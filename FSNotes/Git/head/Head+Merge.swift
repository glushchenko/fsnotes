//
//  Head+Merge.swift
//  Git2Swift
//
//  Created by Damien Giron on 08/08/2016.
//
//

import Foundation
import Cgit2

/// Merge type
///
/// - none:        No entries to merge
/// - upToDate:    All entries up to date
/// - fastForward: Fast forward
/// - normal:      Nomral merge
public enum MergeType {
    case none
    case upToDate
    case fastForward
    case normal
}

// MARK: - Head extension for merging
extension Head {

    /// Head analysis
    ///
    /// - parameter branch: branch to analysis
    ///
    /// - throws: GitError
    ///
    /// - returns: MergeType résult
    public func analysis(branch: Branch) throws -> MergeType {
        
        // Find oid
        var oid = try branch.targetCommit().oid
        
        // Find annotated commit
        let annotatedCommit = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        defer {
            if let ptr = annotatedCommit.pointee {
                git_annotated_commit_free(ptr)
            }
            annotatedCommit.deinitialize(count: 1)
            annotatedCommit.deallocate()
        }
        
        // Find annoted commit
        var error = git_annotated_commit_lookup(annotatedCommit, repository.pointer.pointee, &oid.oid)
        if (error != 0) {
            throw gitUnknownError("Analysis : unable to create annotated commit", code: error)
        }
        
        // Allow fast-forward or normal merge
        var preference : git_merge_preference_t = GIT_MERGE_PREFERENCE_NONE
        
        // Merge analysis
        var analysis = GIT_MERGE_ANALYSIS_NONE
        error = git_merge_analysis(&analysis, &preference, repository.pointer.pointee, annotatedCommit, 1)
        if (error != 0) {
            throw gitUnknownError("Unable to analysis", code: error)
        }
        
        /*
        print("GIT_MERGE_ANALYSIS_NONE : \(analysis.rawValue & GIT_MERGE_ANALYSIS_NONE.rawValue)")
        print("GIT_MERGE_ANALYSIS_NORMAL : \(analysis.rawValue & GIT_MERGE_ANALYSIS_NORMAL.rawValue)")
        print("GIT_MERGE_ANALYSIS_UP_TO_DATE : \(analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue)")
        print("GIT_MERGE_ANALYSIS_FASTFORWARD : \(analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue)")
        print("GIT_MERGE_ANALYSIS_UNBORN : \(analysis.rawValue & GIT_MERGE_ANALYSIS_UNBORN.rawValue)")
        */
        
        // Test up to date
        if (analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue != 0) {
            return .upToDate
        }
        
        // Test fast-froward
        if (analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue != 0) {
            return .fastForward
        }
        
        // Test normal
        if (analysis.rawValue & GIT_MERGE_ANALYSIS_NORMAL.rawValue != 0) {
            return .normal
        }
        
        // Test none
        if (analysis.rawValue & GIT_MERGE_ANALYSIS_NONE.rawValue != 0) {
            return .none
        }
        
        throw GitError.notImplemented(msg: "Index iterator not implemented \(analysis.rawValue).")
    }

    /// Merge branch with signature
    ///
    /// - parameter branch:    branch to merge
    /// - parameter signature: signature for commiter
    /// - parameter progress: Progress object
    ///
    /// - throws: GitError
    ///
    /// - returns: True if branch is merged or false if conflicted files
    public func merge(branch: Branch, signature: Signature, progress: Progress? = nil, project: Project? = nil) throws -> Bool {
        
        // Analysis branch
        let mergeType = try analysis(branch: branch)
        
        switch (mergeType) {
        case .upToDate:
            return true
        case .fastForward:
            try fastForward(branch: branch, signature: signature, progress: progress)
            return true
        case .normal:
            return try normalMerge(branch: branch, signature: signature, progress: progress, project: project)
        case .none:
            throw GitError.unableToMerge(msg: "Unmergeable branch \(branch)")
        }
    }

    /// Internal fast forward
    ///
    /// - parameter branch:    branch to merge
    /// - parameter signature: signature for commiter
    /// - parameter progress: Progress object
    ///
    /// - throws: GitError
    private func fastForward(branch: Branch, signature: Signature, progress: Progress? = nil) throws {
        
        // Update reference target
        try targetReference().updateTargetCommit(commit: try branch.targetCommit(), message: "Merge '\(branch.name)': Fast forward")
        
        // Checkout force
        try checkout(tree: revTree(), type: .force, progress: progress)
    }

    /// Internal normal merge
    ///
    /// - parameter branch:    branch to merge
    /// - parameter signature: signature for commiter
    /// - parameter progress: Progress object
    ///
    /// - throws: GitError
    ///
    /// - returns: True if branch is merged or false if conflicted files
    private func normalMerge(branch: Branch, signature: Signature, progress: Progress? = nil, project: Project? = nil) throws -> Bool {
        
        // Merge index
        let mergeIndexPtr = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)

        // Merge
        let tCommit = try targetCommit()
        let bCommit = try branch.targetCommit()
        let error = git_merge_commits(mergeIndexPtr, repository.pointer.pointee, tCommit.pointer.pointee, bCommit.pointer.pointee, nil)
        
        if (error != 0) {
            
            // Dealloc
            mergeIndexPtr.deinitialize(count: 1)
            mergeIndexPtr.deallocate()
            
            throw gitUnknownError("Failed to merge \(branch.name) to HEAD", code: error)
        }
        
        // Create index
        let mergeIndex = Index(repository: repository, idx: mergeIndexPtr)
        
        // Check conflicts
        if (mergeIndex.conflicts) {
            
            // Create annotated commit
            let annotatedCommit = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
            defer {
                if let ptr = annotatedCommit.pointee {
                    git_annotated_commit_free(ptr)
                }
                annotatedCommit.deinitialize(count: 1)
                annotatedCommit.deallocate()
            }
            
            // Init annoted commit
            var oid = try branch.targetCommit().oid
            var error = git_annotated_commit_lookup(annotatedCommit, repository.pointer.pointee, &oid.oid)
            if (error != 0) {
                throw gitUnknownError("Unable to annotated commit \(oid.sha())", code: error)
            }
            
            // Write conflicts
            var merge_opts = git_merge_options()
            merge_opts.version = 1
            var checkout_opts = git_checkout_options()
            checkout_opts.version = 1
            checkout_opts.checkout_strategy = GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue
            
            // Set progress
            checkout_opts.progress_cb = ProgressDelegate.checkoutProgressCallback
            
            // Merge
            error = git_merge(repository.pointer.pointee, annotatedCommit, 1, &merge_opts, &checkout_opts)
            if (error != 0) {
                throw gitUnknownError("Unable to merge conflicted branch \(branch.name)", code: error)
            }
            
            do {
                return try resolveConflicts(annotatedCommit: annotatedCommit, signature: signature)
            } catch {
                print("Automatic conflict resolution failed")
            }
            
            return false
            
        } else {
            
            // Write tree to repository
            let tree = try repository.write(index: mergeIndex)

            // Commit
            _ = try repository.createCommit(tree: tree,
                                            parents: [try targetCommit(), try branch.targetCommit()],
                                            msg: "Merge branch '\(branch.name)'",
                                            signature: signature)
            
            // Checkout new commit
            try checkout(tree: try repository.head().revTree(), type: .force, progress: progress)
            
            return true
        }
    }
    
    private func conflictPaths(index: OpaquePointer) -> [String]? {
        var iterator: OpaquePointer?
        var result = git_index_conflict_iterator_new(&iterator, index)
        defer {
            git_index_conflict_iterator_free(iterator)
        }
        guard result == GIT_OK.rawValue else {
            return nil
        }
        var paths = [String]()
        var entry: UnsafePointer<git_index_entry>?
        var our: UnsafePointer<git_index_entry>?
        var their: UnsafePointer<git_index_entry>?
        while true {
            result = git_index_conflict_next(&entry, &our, &their, iterator!)
            if result == GIT_ITEROVER.rawValue { break }
            guard result == GIT_OK.rawValue else {
                return nil
            }
            paths.append(String(cString: entry!.pointee.path))
        }
        return paths
    }
    
    private func resolveConflicts(annotatedCommit: UnsafeMutablePointer<OpaquePointer?>, signature: Signature) throws -> Bool {
        var index: OpaquePointer? = nil
        git_repository_index(&index, repository.pointer.pointee)
        
        guard let index = index else { return false }
        guard let paths = conflictPaths(index: index) else { return false }
        
        for path in paths {
            git_index_add_bypath(index, path)
            git_index_conflict_remove(index, path)
        }
        
        git_index_conflict_cleanup(index)
        git_index_write(index)
        
        var headRef: OpaquePointer? = nil
        git_repository_head(&headRef, repository.pointer.pointee)
        
        let rHead = try repository.head()
        let tCommit = try rHead.targetCommit()
        guard let lastCommit = tCommit.pointer.pointee else {
            throw GitError.notFound(ref: "HEAD")
        }
        
        guard let commitID = git_annotated_commit_id(annotatedCommit.pointee) else { return false }
        let parent2 = try repository.commitLookup(oid: OID(withGitOid: commitID.pointee))
        
        var treeOid = git_oid()
        git_index_write_tree(&treeOid, index)
        
        var tree : OpaquePointer? = nil
        git_tree_lookup(&tree, repository.pointer.pointee, &treeOid);
                    
        var sig = UnsafeMutablePointer<UnsafeMutablePointer<git_signature>?>.allocate(capacity: 1)
        defer {
            if let ptr = sig.pointee {
                git_signature_free(ptr)
            }
            
            sig.deinitialize(count: 1)
            sig.deallocate()
        }
        
        // Create now signature
        try signature.now(sig: sig)
        
        
        // Parents
        var parentsPtr : UnsafeMutablePointer<OpaquePointer?>? = nil
        defer {
            if let ptr = parentsPtr {
                ptr.deinitialize(count: 1)
                ptr.deallocate()
            }
        }
        
        parentsPtr = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 2)
        
        var it = parentsPtr!
        
        it.initialize(to: lastCommit)
        it = it.successor()
        
        it.initialize(to: parent2.pointer.pointee)
        it = it.successor()
        
        
        // Create merge commit
        var commit_id = git_oid()
        let commitError = git_commit_create(&commit_id,
            repository.pointer.pointee,
            "HEAD",
            sig.pointee,
            sig.pointee,
            "UTF-8", "Merge conflict",
            tree,
            2,
           parentsPtr
        )
        
        if (commitError != 0) {
            throw gitUnknownError("Unable to create commit", code: commitError)
        }
        
        git_tree_free(tree)
        git_repository_state_cleanup(repository.pointer.pointee)
        
        return true
    }
}
