//
//  Branch.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation
import Cgit2

/// Branch type
///
/// - local:  Local branch
/// - remote: Remote branch
/// - all:    Local and remote branch
public enum BranchType : UInt32 {
    case local = 1  // GIT_BRANCH_LOCAL
    case remote = 2 // GIT_BRANCH_REMOTE
    case all = 3 // GIT_BRANCH_ALL
}

/// Convert a Git2Swift branch to a libgit2 branch type
///
/// - parameter type: Git2Swift branch
///
/// - returns: libgit2 branch
func git_convert_branch_type(_ type: BranchType) -> git_branch_t {
    
    switch type {
    case .local:
        return GIT_BRANCH_LOCAL
    case .remote:
        return GIT_BRANCH_REMOTE
    case .all:
        return GIT_BRANCH_ALL
    }
}

/// Convert a libgit2 branch to Git2Swift branch.
///
/// - parameter type: Libgit2 branch
///
/// - returns: Git2Swift branch
func git_convert_from_git_branch_t(_ type: git_branch_t) -> BranchType {
    switch(type) {
    case GIT_BRANCH_LOCAL :
        return BranchType.local
    case GIT_BRANCH_REMOTE :
        return BranchType.remote
    default :
        return BranchType.all
    }
}

/// Define a git branch
public class Branch : Reference {
    
    /// Type of branch
    public let type: BranchType
    
    lazy public var shortName : String = {
        do {
            return try Branch.getSpecInfo(spec: self.name, type: self.type).name
        } catch {
            return self.name
        }
    } ()
    
    /// Decode rbanch spec in name and type
    ///
    /// - parameter spec: Full spec
    /// - parameter type: Known type for optimisation (may be null)
    ///
    /// - throws: GitError
    ///
    /// - returns: Typle (name, type)
    public static func getSpecInfo(spec: String, type: BranchType? = nil) throws -> (name: String, type: BranchType) {
        
        // Test local
        if ((type != nil && type! == .local) || spec.hasPrefix("refs/heads/")) {
            let startIndex = spec.index(spec.startIndex, offsetBy: 11)
            let name = String(spec[startIndex...])
            return (name, BranchType.local)
            // Test remote
        } else if ((type != nil && type! == .remote) || spec.hasPrefix("refs/remotes/")) {
            let startIndex = spec.index(spec.startIndex, offsetBy: 13)
            let name = String(spec[startIndex...])
            return (name, BranchType.local)
        } else {
            throw GitError.invalidSpec(spec: spec)
        }
    }
    
    /// Constructor with repository, name and libgit2 pointer
    ///
    /// - parameter repository: Git2Swift repository
    /// - parameter name:       Name of the branch
    /// - parameter pointer:    libgit2 reference pointer
    ///
    /// - throws: GitError on init error
    ///
    /// - returns: Git2Swift branch
    override init(repository: Repository, name: String, pointer: UnsafeMutablePointer<OpaquePointer?>) throws {
        
        // Set type
        if (git_reference_is_remote(pointer.pointee) == 1) {
            type = .remote
        } else {
            type = .local
        }
        
        try super.init(repository: repository, name: name, pointer: pointer)
    }
    
    /// Constructor with repository, libgit2 pointer and type.
    ///
    /// - parameter repository: Git2Swift repository
    /// - parameter pointer:    libgit2 reference pointer
    /// - parameter type:       Branch type
    ///
    /// - throws: GitError on init error
    ///
    /// - returns: Git2Swift branch
    init(repository: Repository, pointer: UnsafeMutablePointer<OpaquePointer?>, type: BranchType) throws {
        self.type = type
        
        // Read name from pointer
        let name = git_string_converter(git_reference_name(pointer.pointee))
        
        try super.init(repository: repository, name: name, pointer: pointer)
    }
}
