//
//  Tree.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation
import Cgit2

/// Tree Definition
public class Tree {
    
    let repository : Repository
    
    /// Internal libgit2 tree
    internal let tree : UnsafeMutablePointer<OpaquePointer?>
    
    /// Init with libgit2 tree
    ///
    /// - parameter repository: Git2Swift repository
    /// - parameter tree:       Libgit2 tree pointer
    ///
    /// - returns: Tree
    init(repository: Repository, tree : UnsafeMutablePointer<OpaquePointer?>) {
        self.tree = tree
        self.repository = repository
    }
    
    deinit {
        
        if let ptr = tree.pointee {
            git_tree_free(ptr)
        }
        
        tree.deinitialize(count: 1)
        tree.deallocate()
    }
    
    
    /// Find entry by path.
    ///
    /// - parameter byPath: Path of file
    ///
    /// - throws: GitError
    ///
    /// - returns: TreeEntry or nil
    public func entry(byPath: String) throws -> TreeEntry? {
        
        // Entry
        let treeEntry = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Find tree entry
        let error = git_tree_entry_bypath(treeEntry, tree.pointee, byPath)
        switch error {
        case 0:
            return TreeEntry(pointer: treeEntry)
        case GIT_ENOTFOUND.rawValue:
            return nil
        default:
            throw GitError.unknownError(msg: "", code: error, desc: git_error_message())
        }
        
    }
    
    /// Diff
    ///
    /// - parameter other: Other tree
    ///
    /// - returns: Diff
    public func diff(other: Tree) throws -> Diff {
        
        // Create diff
        let diff = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Create diff
        let error = git_diff_tree_to_tree(diff, repository.pointer.pointee,
                                          tree.pointee,
                                          other.tree.pointee, nil)
        if (error == 0) {
            return Diff(pointer: diff)
        } else {
            throw GitError.unknownError(msg: "diff", code: error, desc: git_error_message())
        }
    }
}
