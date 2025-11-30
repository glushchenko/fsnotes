//
//  RepositoryManager.swift
//  Git2Swift
//
//  Created by Damien Giron on 31/07/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation
import Cgit2

/// Repository manager
///
/// Use to init and clear libgit2
public class RepositoryManager {
    
    /// Repository instance count
    private static var count : Int = 0
    
    /// Lock manager
    ///
    /// Used to lock manager when updating repository counter
    private static var lock = NSLock()
    
    /// Find config manager
    ///
    /// - throws: GitError
    ///
    /// - returns: ConfigManager
    public func configManager() throws -> ConfigManager {
        return try ConfigManager()
    }
    
    /// Constructor
    ///
    /// If there is the first contruction, init libgit2 librairy
    public init() {
        
        // Lock
        RepositoryManager.lock.lock()
        
        // Test init lib
        if (RepositoryManager.count == 0) {
            
            // Init git
            git_libgit2_init()
        }
        
        RepositoryManager.count += 1
        
        // Lock
        RepositoryManager.lock.unlock()
    }
    
    /// If there are only one repository, free libgit2 library
    deinit {
        
        // Lock
        RepositoryManager.lock.lock()
        
        RepositoryManager.count -= 1
        if (RepositoryManager.count == 0) {
            // Shutdown git
            git_libgit2_shutdown()
        }
        
        // Lock
        RepositoryManager.lock.unlock()
    }
    
    /// Init new repository at URL
    ///
    /// - parameter url:       Repository URL
    /// - parameter signature: Init signature
    /// - parameter bare:      Create a bare repository
    /// - parameter shared:    Share repository from users
    ///
    /// - throws: GitError
    ///
    /// - returns: Repository
    public func initRepository(at url: URL, signature: Signature, bare: Bool = false, shared : Bool = false) throws -> Repository {
        
        // Create repository
        let repository =  try Repository(initAt: url, manager: self, signature: signature, bare: bare, shared: shared)
        
        // Create initial commit
        _ = try repository.head().index().createInitialCommit(msg: "Initial commit", signature: signature)
        
        return repository
    }
    
    /// Open repository at URL
    ///
    /// - parameter url: Repository URL
    ///
    /// - throws: GitError
    ///
    /// - returns: Repository
    public func openRepository(at url: URL) throws -> Repository {
        
        // Open repository
        return try Repository(openAt: url, manager: self)
    }
    
    /// Clone repository
    ///
    /// - parameter remoteUrl: Remote URL
    /// - parameter url:       Repository URL
    /// - parameter progress: Progress object
    /// - parameter authentication: Authentication handler
    ///
    /// - throws: GitError wrapping libgit2 error
    ///
    /// - returns: Repository
    public func cloneRepository(from remoteUrl: URL,
                                at url: URL,
                                progress: Progress? = nil,
                                authentication: AuthenticationHandler? = nil) throws -> Repository {
        
        // Open repository
        return try Repository(cloneFrom: remoteUrl, at: url, manager: self, authentication: authentication, progress: progress)
    }

    /// Find system signature
    ///
    /// - throws: GitError
    ///
    /// - returns: Signature
    public func systemSignature() throws -> Signature {
        let configManager = try self.configManager()
        
        let systemName = try configManager.readString(key: "user.name")
        let systemEmail = try configManager.readString(key: "user.email")
        
        let name : String
        if systemName.isEmpty {
            name = "Unknown"
        } else {
            name = systemName
        }
        
        let email : String
        if systemEmail.isEmpty {
            email = "unknown@unknown.fr"
        } else {
            email = systemEmail
        }
        
        return Signature(name: name, email: email)
    }
}
