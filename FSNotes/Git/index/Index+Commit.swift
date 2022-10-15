//
//  Index+Commit.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation

// MARK: - Index extension for commit
extension Index {

    /// Create initial commit
    ///
    /// - parameter msg:       Commit message
    /// - parameter signature: Author
    ///
    /// - throws: GitError
    ///
    /// - returns: Commit
    internal func createInitialCommit(msg: String, signature: Signature) throws -> Commit {
        return try repository.createCommit(idx: idx, parent: nil, msg: msg, signature: signature)
    }
    
    /// Create commit
    ///
    /// - parameter msg:       Commit message
    /// - parameter signature: Author
    ///
    /// - throws: GitError
    ///
    /// - returns: Commit
    public func createCommit(msg: String, signature: Signature) throws -> Commit {
        return try repository.createCommit(idx: idx, parent: try repository.head().targetCommit(), msg: msg, signature: signature)
    }
}
