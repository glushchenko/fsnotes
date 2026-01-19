//
//  Branches.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation
import Cgit2

/// Branches manager
public class Branches {

    /// Repository
    public let repository: Repository
    
    /// Constructor with repository
    ///
    /// - parameter repository: Git2Swift repository
    ///
    /// - returns: Branches
    init(repository: Repository) {
        self.repository = repository
    }
    
    /// All branch names
    public func names(type: BranchType = .local) throws -> [String] {
        
        var strs = [String]()
        
        for branch in try all(type: type) {
            strs.append(branch.name)
        }
        
        
        return strs
    }
    
    /// Get branch with full reference name
    ///
    /// - parameter name: Branch name
    ///
    /// - throws: GitError (notFound, invalidSpec)
    ///
    /// - returns: Branch
    public func get(spec: String) throws -> Branch {
        let specInfo = try Branch.getSpecInfo(spec: spec)
        return try get(name: specInfo.name, type: specInfo.type)
    }
    
    /// Get branch by name
    ///
    /// - parameter name: Branch name
    /// - parameter type: Branch type
    ///
    /// - throws: GitError (notFound, invalidSpec)
    ///
    /// - returns: Branch
    public func get(name: String, type: BranchType = .local) throws -> Branch {
        
        // Find reference pointer
        let reference = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Lookup reference
        let error = git_branch_lookup(reference, repository.pointer.pointee, name, git_convert_branch_type(type))
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
        
        return try Branch(repository: repository, name:name, pointer: reference)
    }
    
    /// Create a new branch
    ///
    /// - parameter name:  New branch name
    /// - parameter force: Force creation
    ///
    /// - throws: GitError
    ///
    /// - returns: Branch
    public func create(name: String, force: Bool = false) throws -> Branch {
        
        // Find last commit
        guard let lastCommit = try repository.head().targetCommit().pointer.pointee else {
            throw GitError.notFound(ref: "HEAD")
        }
        
        // new_branch
        let new_branch = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Create branch
        let error = git_branch_create(new_branch, repository.pointer.pointee, name, lastCommit, force ? 1 : 0)
        if (error == 0) {
            return try Branch(repository: repository, name: name, pointer: new_branch)
        } else {
            throw gitUnknownError("Unable to create branch", code: error)
        }
    }
    
    /// Remove a branch by name and type
    ///
    /// - parameter name: Branch name
    /// - parameter type: Branch type
    ///
    /// - throws: GitError
    public func remove(name: String, type: BranchType = .local) throws {
        
        // branch
        let lookup_branch = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        defer {
            if (lookup_branch.pointee != nil) {
                git_reference_free(lookup_branch.pointee)
            }
            lookup_branch.deinitialize(count: 1)
            lookup_branch.deallocate()
        }
        
        // Find type
        let branchType : git_branch_t
        if (type == .remote) {
            branchType = GIT_BRANCH_REMOTE
        } else {
            branchType = GIT_BRANCH_LOCAL
        }
        
        let error = git_branch_lookup(lookup_branch, repository.pointer.pointee,
                                      name, branchType)
        if (error == 0 && lookup_branch.pointee != nil) {
            git_branch_delete(lookup_branch.pointee)
        } else {
            throw gitUnknownError("Unable to delete branch", code: error)
        }
    }
    
    /// Find all branches
    ///
    /// - parameter type: Filter by types
    ///
    /// - throws: GitError
    ///
    /// - returns: Branch iterator
    public func all(type: BranchType = .local) throws -> BranchIterator {
        return BranchIterator(repository: repository, type: type)
    }
}
