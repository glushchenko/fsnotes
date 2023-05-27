//
//  Repository+Init.swift
//  Git2Swift
//
//  Created by Damien Giron on 31/07/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation
import Cgit2

// MARK: - Repository extension for openning
extension Repository {
    
    /// Constructor with URL and manager
    ///
    /// - parameter url:     Repository URL
    /// - parameter manager: Repository manager
    ///
    /// - throws: GitError
    ///
    /// - returns: Repository
    convenience init(openAt url: URL, manager: RepositoryManager) throws {
        
        // Repository pointer
        let repository = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Init repo
        let error = git_repository_open(repository, url.path)
        if (error != 0) {
            repository.deinitialize(count: 1)
            repository.deallocate()
            throw gitUnknownError("Unable to open repository, url: \(url)", code: error)
        }
        
        self.init(at: url, manager: manager, repository: repository)
    }
    
    /// Init new repository at URL
    ///
    /// - parameter url:       Repository URL
    /// - parameter manager:   Repository manager
    /// - parameter signature: Initial commiter
    /// - parameter bare:      Create bare repository
    /// - parameter shared:    Share repository from users
    ///
    /// - throws: GitError
    ///
    /// - returns: Repository
    convenience init(initAt url: URL, manager: RepositoryManager,
                     signature: Signature,
                     bare: Bool,
                     shared : Bool) throws {
        
        // Repository pointer
        let repository = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Options
        var options = git_repository_init_options()
        
        options.version = 1
        
        if bare {
            // Set bare
            options.flags = GIT_REPOSITORY_INIT_BARE.rawValue
        }
        
        if shared {
            // Used shared
            options.mode = GIT_REPOSITORY_INIT_SHARED_ALL.rawValue
        }
        
        // Init repo
        let error = git_repository_init_ext(repository, url.path, &options)
        //let error = git_repository_init(repository, url.path, bare ? 1 : 0)
        if (error != 0) {
            repository.deinitialize(count: 1)
            repository.deallocate()
            throw gitUnknownError("Unable to init repository, url: \(url) (bare \(bare))", code: error)
        }
        
        self.init(at: url, manager: manager, repository: repository)
    }
    
    /// Clone a repository at URL
    ///
    /// - parameter url:            URL to remote git
    /// - parameter at:             URL to local respository
    /// - parameter manager:        Repository manager
    /// - parameter authentication: Authentication
    /// - parameter progress:       Object containing progress callbacks
    ///
    /// - throws: GitError wrapping libgit2 error
    ///
    /// - returns: Repository
    convenience init(cloneFrom url: URL,
                     at: URL,
                     manager: RepositoryManager,
                     authentication: AuthenticationHandler? = nil,
                     progress: Progress? = nil) throws {
        
        // Repository pointer
        let repository = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        var opts = git_clone_options()
        opts.version = 1
        
        // General checkouts
        opts.checkout_opts.version = 1
        opts.checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue
        opts.checkout_opts.progress_cb = ProgressDelegate.checkoutProgressCallback
        
        // General fetchs
        opts.fetch_opts.version = 1
        opts.fetch_opts.prune = GIT_FETCH_PRUNE_UNSPECIFIED
        opts.fetch_opts.update_fetchhead = 1
        opts.fetch_opts.callbacks.version = 1
        opts.fetch_opts.proxy_opts.version = 1

        // Set fetch progress
        opts.fetch_opts.callbacks.transfer_progress = ProgressDelegate.fetchProgressCallback
        
        // Check handler
        if (authentication != nil) {
            setAuthenticationCallback(&opts.fetch_opts.callbacks, authentication: authentication!)
        }
        
        // Clone repository
        let error = git_clone(repository, url.absoluteString, at.path, &opts)
        if (error != 0) {
            repository.deinitialize(count: 1)
            repository.deallocate()
            throw gitUnknownError("Unable to clone repository, from \(url) to: \(at)", code: error)
        }
        
        self.init(at: at, manager: manager, repository: repository)
    }
}
