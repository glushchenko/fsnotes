//
//  Remotes.swift
//  Git2Swift
//
//  Created by Damien Giron on 17/08/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

import Cgit2

/// Manage remote repository
public class Remotes {
    
    /// Repository
    private let repository : Repository
    
    /// Constructor with repository manager
    ///
    /// - parameter repository: Repository
    ///
    /// - returns: Remotes
    init(repository: Repository) {
        self.repository = repository
    }
    
    /// Find remote names
    ///
    /// - throws: GitError
    ///
    /// - returns: String array
    public func remoteNames() throws -> [String] {
        
        // Store remote names
        var remotes = git_strarray()
        
        // List remotes
        let error = git_remote_list(&remotes, repository.pointer.pointee)
        if (error != 0) {
            throw gitUnknownError("Unable to list remotes", code: error)
        }
        
        return git_strarray_to_strings(&remotes)
    }
    
    /// Find remote by name.
    ///
    /// - parameter name: Remote name
    ///
    /// - throws: GitError
    ///
    /// - returns: Remote
    public func get(remoteName: String) throws -> Remote {
        
        // Remote pointer
        let remote = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Lookup remote
        let error = git_remote_lookup(remote, repository.pointer.pointee, remoteName)
        if (error != 0) {
            
            remote.deinitialize(count: 1)
            remote.deallocate()
            
            switch(error) {
            case GIT_ENOTFOUND.rawValue:
                throw GitError.notFound(ref: remoteName)
            case GIT_EINVALIDSPEC.rawValue:
                throw GitError.invalidSpec(spec: remoteName)
            default:
                throw gitUnknownError("Unable to lookup remote \(remoteName)", code: error)
            }
        }
        
        return Remote(repository: repository, pointer: remote, name: remoteName)
    }
    
    
    /// Create remote
    ///
    /// - parameter name: Remote name
    /// - parameter url:  URL
    ///
    /// - throws: GitError
    ///
    /// - returns: Remote
    public func create(name: String, url: URL) throws -> Remote {
        
        // Remote pointer
        let remote = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Create remote
        let error = git_remote_create(remote, repository.pointer.pointee,
                                      name, url.path)
        if (error != 0) {
            switch(error) {
            case GIT_EINVALIDSPEC.rawValue:
                throw GitError.invalidSpec(spec: name)
            case GIT_EEXISTS.rawValue:
                throw GitError.alreadyExists(ref: name)
            default:
                throw gitUnknownError("Unable to create remote \(name)",
                    code: error)
            }
        }
        
        return Remote(repository: repository, pointer: remote, name: name)
    }
    
    
    /// Remove remote
    ///
    /// - parameter name: Remote name
    ///
    /// - throws: GitError
    public func remove(name: String) throws {
        
        // remove remote
        let error = git_remote_delete(repository.pointer.pointee, name)
        if (error != 0) {
            throw gitUnknownError("Unable to remove remote \(name)",
                code: error)
        }
    }
}
