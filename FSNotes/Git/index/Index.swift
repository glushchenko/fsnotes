//
//  Index.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation
import Cgit2

/// Git index
public class Index {
    
    /// Git2Swift repository
    public let repository : Repository
    
    /// Libgit2 index pointer
    internal let idx: UnsafeMutablePointer<OpaquePointer?>
  
    /// Has conflict in index
    public var conflicts : Bool {
        get {
            return git_index_has_conflicts(idx.pointee) == 1
        }
    }
    
    /// Constructor with repository and libgit2 index pointer
    ///
    /// - parameter repository: Git2Swift repository
    /// - parameter idx:        Libgit2 index
    ///
    /// - returns: Index
    init(repository: Repository, idx: UnsafeMutablePointer<OpaquePointer?>) {
        self.repository = repository
        self.idx = idx
    }
    
    /// Constructor with repository and return repository index
    ///
    /// - parameter repository: Git2Swift repository
    ///
    /// - throws: GitError
    ///
    /// - returns: Index
    convenience init(repository: Repository) throws {
    
        let idx = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Create index
        let error = git_repository_index(idx, repository.pointer.pointee)
        if (error != 0) {
            
            idx.deinitialize(count: 1)
            idx.deallocate()
            
            throw gitUnknownError("Unable to init repository index", code: error)
        }
        
        self.init(repository: repository, idx: idx)
    }
    
    deinit {
        if let ptr = idx.pointee {
            git_index_free(ptr)
        }
        idx.deinitialize(count: 1)
        idx.deallocate()
    }
    
}
