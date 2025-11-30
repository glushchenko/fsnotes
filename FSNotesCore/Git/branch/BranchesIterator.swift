//
//  BranchesIterator.swift
//  Git2Swift
//
//  Created by Damien Giron on 11/08/2016.
//
//

import Foundation
import Cgit2

/// Branch iterator
public class BranchIterator : Sequence, IteratorProtocol {
 
    /// LibGit2 iterator pointer
    private var branch_iterator : UnsafeMutablePointer<OpaquePointer?>
    
    /// LibGit2 repository pointer
    private let repository: Repository
    
    /// Constructor with repository and type
    ///
    /// - parameter repository: Repository
    /// - parameter type:       Type
    ///
    /// - returns: Branch iterator
    init(repository : Repository, type: BranchType) {
        
        self.repository = repository
        
        // Pointer of branch iterator
        branch_iterator = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Init iterator
        git_branch_iterator_new(branch_iterator, repository.pointer.pointee, git_convert_branch_type(type))
    }
    
    deinit {
        if let ptr = branch_iterator.pointee {
            git_branch_iterator_free(ptr)
        }
        branch_iterator.deinitialize(count: 1)
        branch_iterator.deallocate()
    }
    
    /// Find next branch
    ///
    /// - returns: Next branch or nil for the end
    public func next() -> Branch? {
        
        // Next branch pointer
        let branch = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Next branch type
        let type = UnsafeMutablePointer<git_branch_t>.allocate(capacity: 1)
        defer {
            type.deinitialize(count: 1)
            type.deallocate()
        }
        
        // find next
        let result = git_branch_next(branch, type, branch_iterator.pointee)
        
        // Test next
        if (result != GIT_ITEROVER.rawValue) {
            return try? Branch(repository: repository, pointer: branch, type: git_convert_from_git_branch_t(type.pointee))
        } else {
            // End
            return nil
        }
    }
}
