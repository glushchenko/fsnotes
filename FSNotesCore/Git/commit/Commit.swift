//
//  Commit.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation
import Cgit2

/// Wrap a commit
public class Commit : Object {
    
    private let repository : Repository
    
    /// LibGit2 commit pointer
    internal let pointer : UnsafeMutablePointer<OpaquePointer?>
    
    /// OID
    public let oid: OID
    
    /// Commit summary
    lazy public var summary : String = {
        git_string_converter(git_commit_summary(self.pointer.pointee))
    } ()
    
    /// Commit body
    lazy public var body : String = {
        git_string_converter(git_commit_body(self.pointer.pointee))
    } ()
    
    /// Commit author
    lazy public var author : Signature = {
        Signature(sig: git_commit_author(self.pointer.pointee))
    } ()
    
    /// Commit commiter
    lazy public var committer : Signature = {
        Signature(sig: git_commit_committer(self.pointer.pointee))
    } ()
    
    /// Commit date
    lazy public var date : Date = {
        Date(timeIntervalSince1970: TimeInterval(git_commit_time(self.pointer.pointee)))
    } ()
    
    /// Commit TimeZone
    lazy public var timeZone : TimeZone? = {
        TimeZone(secondsFromGMT: Int(git_commit_time_offset(self.pointer.pointee)) * 60)
    } ()
    
    /// Constructor with libgit2 pointer and OID
    ///
    /// - parameter pointer: libgit2 commit pointer
    /// - parameter oid:     OID
    ///
    /// - returns: Commit
    init(repository : Repository, pointer: UnsafeMutablePointer<OpaquePointer?>, oid: OID) {
        self.repository = repository
        self.pointer = pointer
        self.oid = oid
    }
    
    deinit {
        if let ptr = pointer.pointee {
            git_commit_free(ptr)
        }
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }
    
    public func tree() throws -> Tree {
        
        // Tree
        let tree = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Find tree from commit
        let error = git_commit_tree(tree, pointer.pointee)
        if (error == 0) {
            return Tree(repository: repository, tree: tree)
        } else {
            throw GitError.unknownError(msg: "Unable to find tree from commit",
                                        code: error, desc: git_error_message())
        }
    }
    
    public func getDate() -> String {
        date.string(format: "yyyy-MM-dd HH:mm:ss")
    }
}
