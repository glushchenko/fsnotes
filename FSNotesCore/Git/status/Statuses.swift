//
//  Statuses.swift
//  Git2Swift
//
//  Created by Damien Giron on 12/08/2016.
//
//

import Foundation
import Cgit2

/// Manage current repository statuses
public class Statuses {
    
    /// Git2Swift repository
    public let repository : Repository
    
    /// Clean working directory property : true if clean, false in other cases
    public var workingDirectoryClean: Bool {
        get {
            do {
                return try all().next() == nil
            } catch {
                print(error.localizedDescription)
                return false
            }
        }
    }
    
    /// Constructor with Git2Swift repository
    ///
    /// - parameter repository: Repository
    ///
    /// - returns: Statuses
    init(repository: Repository) {
        self.repository = repository
    }
    
    /// Return all statuses in an iterator
    ///
    /// - throws: GitError wrapping libgit2 error
    ///
    /// - returns: Statuses iterator
    public func all() throws -> StatusIterator {
        
        var opt = git_status_options()
        opt.version = 1 // Use #define 1
        
        // Set defaults flags
        opt.flags = (GIT_STATUS_OPT_INCLUDE_IGNORED.rawValue |
            GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue |
            GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue)
        
        return try StatusIterator(repository: repository, opt: &opt)
    }
}
