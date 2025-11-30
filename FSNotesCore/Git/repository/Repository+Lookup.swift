//
//  Repository+Lookup.swift
//  Git2Swift
//
//  Created by Dami on 31/07/2016.
//
//

import Foundation
import Cgit2

/// Git reference lookup
///
/// - parameter repository: Libgit2 repository pointer
/// - parameter name:       Reference name
///
/// - throws: GitError
///
/// - returns: Libgit2 reference pointer
internal func gitReferenceLookup(repository: UnsafeMutablePointer<OpaquePointer?>,
                                 name: String) throws -> UnsafeMutablePointer<OpaquePointer?> {
    
    // Find reference pointer
    let reference = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    
    // Lookup reference
    let error = git_reference_lookup(reference, repository.pointee, name)
    if (error != 0) {
        
        reference.deinitialize(count: 1)
        reference.deallocate()
        
        // 0 on success, GIT_ENOTFOUND, GIT_EINVALIDSPEC or an error code.
        switch (error) {
        case GIT_ENOTFOUND.rawValue :
            throw GitError.notFound(ref: name)
        case GIT_EINVALIDSPEC.rawValue:
            throw GitError.invalidSpec(spec: name)
        default:
            throw gitUnknownError("Unable to lookup reference \(name)", code: error)
        }
    }
    
    return reference
}

// MARK: - Repository extension for lookup
extension Repository {

    /// Lookup reference
    ///
    /// - parameter name: Refrence name
    ///
    /// - throws: GitError
    ///
    /// - returns: Refernce
    public func referenceLookup(name: String) throws -> Reference {
        return try Reference(repository: self, name: name, pointer: try gitReferenceLookup(repository: pointer, name: name))
    }

    /// Lookup a tree
    ///
    /// - parameter tree_id: Tree OID
    ///
    /// - throws: GitError
    ///
    /// - returns: Tree
    public func treeLookup(oid tree_id: OID) throws -> Tree {
        
        // Create tree
        let tree : UnsafeMutablePointer<OpaquePointer?> = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        var oid = tree_id.oid
        let error = git_tree_lookup(tree, pointer.pointee, &oid)
        if (error != 0) {
            
            tree.deinitialize(count: 1)
            tree.deallocate()
            
            throw gitUnknownError("Unable to lookup tree", code: error)
        }
        
        return Tree(repository: self, tree: tree)
    }
    
    /// Lookup a commit
    ///
    /// - parameter commit_id: OID
    ///
    /// - throws: GitError
    ///
    /// - returns: Commit
    public func commitLookup(oid commit_id: OID) throws -> Commit {
        
        // Create tree
        let commit : UnsafeMutablePointer<OpaquePointer?> = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        var oid = commit_id.oid
        let error = git_commit_lookup(commit, pointer.pointee, &oid)
        if (error != 0) {
            
            commit.deinitialize(count: 1)
            commit.deallocate()
            
            throw gitUnknownError("Unable to lookup commit", code: error)
        }
        
        return Commit(repository: self, pointer: commit, oid: OID(withGitOid: oid))
    }

    /// Lookup a blob
    ///
    /// - parameter blob_id: OID
    ///
    /// - throws: GitError
    ///
    /// - returns: Blob
    public func blobLookup(oid blob_id: OID) throws -> Blob {

        // Create tree
        let blob : UnsafeMutablePointer<OpaquePointer?> = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)

        var oid = blob_id.oid
        let error = git_blob_lookup(blob, pointer.pointee, &oid)
        if error != 0 {

            blob.deinitialize(count: 1)
            blob.deallocate()

            throw gitUnknownError("Unable to lookup blob", code: error)
        }

        return Blob(blob: blob)
    }
}
