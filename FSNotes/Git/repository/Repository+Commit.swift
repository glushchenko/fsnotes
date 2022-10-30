//
//  Repository+Commit.swift
//  Git2Swift
//
//  Created by Damien Giron on 11/08/2016.
//
//

import Foundation
import Cgit2

// MARK: - Repository extension for commit
extension Repository {

    /// Internal create commit from libgit2 index
    ///
    /// - parameter idx:       libgit2 index pointer
    /// - parameter parent:    Parent commite
    /// - parameter msg:       Message commit
    /// - parameter signature: Commit signature
    ///
    /// - throws: GitError
    ///
    /// - returns: Commit
    internal func createCommit(idx: UnsafeMutablePointer<OpaquePointer?>,
                               parent: Commit?,
                               msg: String,
                               signature: Signature) throws -> Commit {
        
        // Create tree index
        var tree_id = git_oid()
        let error = git_index_write_tree(&tree_id, idx.pointee)
        if (error != 0) {
            throw gitUnknownError("Unable to write index to tree", code: error)
        }
        
        // Tree oid
        let oid = OID(withGitOid: tree_id)
        
        // Lookup tree
        let tree = try treeLookup(oid: oid)
        
        let parents : [Commit]
        if (parent == nil) {
            parents = []
        } else {
            parents = [parent!]
        }
        
        return try createCommit(tree: tree, parents: parents, msg: msg, signature: signature)
    }
    
    /// Internal create commit with tree
    ///
    /// - parameter tree:      Tree
    /// - parameter parents:   Parent commit
    /// - parameter msg:       Commit message
    /// - parameter signature: Commit signature
    ///
    /// - throws: GitError
    ///
    /// - returns: Commit
    internal func createCommit(tree: Tree,
                               parents: [Commit],
                               msg: String,
                               signature: Signature) throws -> Commit {
        
        // Create signature
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
        
        // Find parents
        let parentsCount = parents.count
        
        
        var parentsPtr : UnsafeMutablePointer<OpaquePointer?>? = nil
        defer {
            if let ptr = parentsPtr {
                ptr.deinitialize(count: 1)
                ptr.deallocate()
            }
        }
        
        if (parentsCount > 0) {
            parentsPtr = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: parentsCount)
            
            var it = parentsPtr!
            for parent in parents {
                it.initialize(to: parent.pointer.pointee)
                it = it.successor()
            }
        }
        
        // Create empty commit
        var commit_id = git_oid()
        let error = git_commit_create(&commit_id,
                                  pointer.pointee, "HEAD",
                                  sig.pointee, sig.pointee,
                                  "UTF-8", msg,
                                  tree.tree.pointee,
                                  parentsCount,
                                  parentsPtr)
        if (error != 0) {
            throw gitUnknownError("Unable to create commit", code: error)
        }
        
        return try commitLookup(oid: OID(withGitOid: commit_id))
    }
    
    /// Write index and return tree
    ///
    /// - parameter index: Git2Swift index
    ///
    /// - throws: GitError
    ///
    /// - returns: Tree
    public func write(index: Index) throws -> Tree {
        
        var gOid = git_oid()
        
        // Write tree to index
        let error = git_index_write_tree_to(&gOid, index.idx.pointee, pointer.pointee)
        if (error != 0) {
            throw gitUnknownError("Unable to write index to repository", code: error)
        }
        
        return try treeLookup(oid: OID(withGitOid: gOid))
    }
}
