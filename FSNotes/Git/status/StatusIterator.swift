//
//  StatusIterator.swift
//  Git2Swift
//
//  Created by Damien Giron on 12/08/2016.
//
//

import Foundation
import Cgit2

/// Statuses iterator
public class StatusIterator : Sequence, IteratorProtocol {
    
    /// Statuses libgit2 pointer
    private let statuses : UnsafeMutablePointer<OpaquePointer?>
    
    ///
    /// Statues count.
    ///
    private let count : Int
    
    
    /// Statuses count
    private var index = 0
    
    
    /// Costructor with options
    ///
    /// - parameter repository: Git2Swift repository
    /// - parameter opt:        libgit2 status options
    ///
    /// - throws: GitError wrapping libgit2 errors
    ///
    /// - returns: StatuesIterator
    init(repository : Repository, opt: inout git_status_options) throws {
        
        // Init status list
        statuses = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        let error = git_status_list_new(statuses, repository.pointer.pointee, &opt)
        if (error != 0) {
            throw gitUnknownError("Unable to list status", code: error)
        }
        
        // List count
        count = git_status_list_entrycount(statuses.pointee);
    }
    
    /// Free iterator list
    deinit {
        if let ptr = statuses.pointee {
            git_status_list_free(ptr)
        }
        statuses.deinitialize(count: 1)
        statuses.deallocate()
    }
    
    /// Next value or nil
    public func next() -> Status? {
        
        if (index < count) {
            
            // Find status at index.
            let entry = git_status_byindex(statuses.pointee, index);
            
            // Inc index
            index += 1
            
            if entry == nil {
                return nil
            }

            do {
                let result = try Status(entry: entry!)
                return result
            } catch {
                print(error.localizedDescription)
                return nil
            }
        } else {
            return nil
        }
        
    }
}
