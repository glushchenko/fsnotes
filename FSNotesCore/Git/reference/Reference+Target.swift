//
//  Reference+Target.swift
//  Git2Swift
//
//  Created by Damien Giron on 08/08/2016.
//
//

import Foundation
import Cgit2

// MARK: - Reference extension for target
extension Reference {
    
    /// Target commit
    ///
    /// - throws: GitError
    ///
    /// - returns: Reference
    public func targetCommit() throws -> Commit {
        
        
        // Create commit
        let target = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Find commit
        let error = git_reference_peel(target, pointer.pointee, GIT_OBJECT_COMMIT)
        if (error != 0) {
            
            target.deinitialize(count: 1)
            target.deallocate()
            
            switch error {
                case GIT_EAMBIGUOUS.rawValue:
                    throw GitError.ambiguous(msg: "HEAD -> target")
                case GIT_ENOTFOUND.rawValue:
                    throw GitError.notFound(ref: "HEAD")
            default:
                throw gitUnknownError("HEAD -> target", code: error)
            }
        }
        
        // Read oid
        let gOid = git_commit_id(target.pointee)
        if (gOid == nil) {
            throw GitError.notFound(ref: "nil")
        }
        
        // Set target
        return Commit(repository: repository, pointer: target, oid: OID(withGitOid: gOid!.pointee))
    }
    
    /// Update target commit
    ///
    /// - parameter commit:  New target commit
    /// - parameter message: log message
    ///
    /// - throws: GitError
    public func updateTargetCommit(commit: Commit, message: String) throws {
        
        let reference = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        defer {
            if let ptr = reference.pointee {
                git_reference_free(ptr)
            }
            reference.deinitialize(count: 1)
            reference.deallocate()
        }
        
        var oid = commit.oid
        if (refType == ReferenceType.oid) {
            let error = git_reference_set_target(reference, self.pointer.pointee, &oid.oid, message)
            if (error != 0) {
                switch error {
                case GIT_EMODIFIED.rawValue:
                    throw GitError.modifiedElsewhere(ref: name)
                default:
                    throw gitUnknownError("Unable to set target", code: error)
                }
            }
            
        } else {
            guard let sha = oid.sha() else {
                throw GitError.invalidSHA(sha: "nil")
            }
            let error = git_reference_symbolic_set_target(reference, self.pointer.pointee, sha, message)
            if (error != 0) {
                let msg = "Unable to set (symbolic) target"
                switch error {
                case GIT_EINVALIDSPEC.rawValue:
                    throw GitError.invalidSpec(spec: name)
                default:
                    throw gitUnknownError(msg, code: error)
                }
            }
        }
    }
}
