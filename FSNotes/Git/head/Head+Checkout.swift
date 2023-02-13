//
//  Head+Checkout.swift
//  Git2Swift
//
//  Created by Damien Giron on 07/08/2016.
//
//

import Foundation
import Cgit2

/// Define checkout type
///
/// - none:            default checkout
/// - safe:            todo
/// - recreateMissing: todo
/// - force:           todo
public enum CheckoutType {
    case none
    case safe
    case recreateMissing
    case force
}

/// Reset type
///
/// - soft:  todo
/// - mixed: todo
/// - hard:  todo
public enum ResetType {
    case soft
    case mixed
    case hard
}

// MARK: - Head extension for checkout
extension Head {
    
    /// Checkout a branch and swith HEAD to this
    ///
    /// - parameter branch: branch
    /// - parameter progress: Progress object
    ///
    /// - throws: GitError 
    ///    - GitError.NOT_FOUND : if branch not found
    ///    - GitError.UNKNOW_ERROR : for unknow error
    public func checkout(branch: Branch, progress: Progress? = nil) throws {
        
        // Checkout new tree
        try checkout(tree: try branch.revTree(), type: .safe, progress: progress)
        
        // Set head
        let error = git_repository_set_head(repository.pointer.pointee, branch.name)
        if (error != 0) {
            throw gitUnknownError("Unable to switch to '\(branch.name)' branch", code: error)
        }
    }
    
    /// Checkout a tag and swith HEAD to this
    ///
    /// - parameter tag: tag
    /// - parameter progress: Progress object
    ///
    /// - throws: GitError
    ///    - GitError.NOT_FOUND : if branch not found
    ///    - GitError.UNKNOW_ERROR : for unknow error
    public func checkout(tag: Tag, progress: Progress? = nil) throws {
        
        // Checkout new tree
        try checkout(tree: try tag.revTree(), type: .safe, progress: progress)
        
        // Set repository to tag
        let error = git_repository_set_head(repository.pointer.pointee, tag.name)
        if (error != 0) {
            throw gitUnknownError("Unable to switch to '\(tag.name)' tag", code: error)
        }
    }
    
    /// Checkout tree to Head
    ///
    /// - parameter tree: File tree
    /// - parameter type: Checkout type
    /// - parameter progress: Progress object
    ///
    /// - throws: GitError
    public func checkout(tree: Tree, type: CheckoutType, progress: Progress? = nil) throws {
        
        // Select checkout strategy
        var opts = git_checkout_options()
        opts.version = 1
        
        // Set progress
        setCheckoutProgressHandler(options: &opts, progress: progress)
        
        switch type {
        case .none:
            opts.checkout_strategy = GIT_CHECKOUT_NONE.rawValue;
        case .safe:
            opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue;
        case .recreateMissing:
            opts.checkout_strategy = GIT_CHECKOUT_RECREATE_MISSING.rawValue;
        case .force:
            opts.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue;
        }
        
        // Checkout new tree
        let error = git_checkout_tree(repository.pointer.pointee, tree.tree.pointee, &opts);
        if (error != 0) {
            throw gitUnknownError("Unable to checkout to tree", code: error)
        }
    }
    
    /// Reset head.
    ///
    /// - parameter type: Reset type
    /// - parameter progress: Progress object
    ///
    /// - throws: GitError
    public func reset(type: ResetType, progress: Progress? = nil) throws {
        
        // Set checkout option
        var opts = git_checkout_options()
        opts.version = 1
        
        // Set progress
        setCheckoutProgressHandler(options: &opts, progress: progress)
        
        let gType : git_reset_t
        
        switch (type) {
        case .soft :
            gType = GIT_RESET_SOFT
        case .mixed :
            gType = GIT_RESET_MIXED
        case .hard :
            gType = GIT_RESET_HARD
        }
        
        // Reset directory
        let error = git_reset(repository.pointer.pointee, try targetCommit().pointer.pointee, gType, &opts)
        if (error != 0) {
            throw gitUnknownError("Unable to reset 'HEAD'", code: error)
        }
    }
    
    public func forceCheckout(branch: Branch, progress: Progress? = nil) throws {
        
        // Checkout new tree
        try checkout(tree: try branch.revTree(), type: .force, progress: progress)
        
        // Set head
        let error = git_repository_set_head(repository.pointer.pointee, branch.name)
        if (error != 0) {
            throw gitUnknownError("Unable to switch to '\(branch.name)' branch", code: error)
        }
    }
}
