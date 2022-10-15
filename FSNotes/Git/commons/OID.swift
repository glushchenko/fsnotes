//
//  OID.swift
//  Git2Swift
//
//  Created by Damien Giron on 31/07/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation
import Cgit2

/// Define git OID
public struct OID {
    
    /// LibGit2 OID
    internal var oid = git_oid()
    
    /// Init with libgit2 OID
    ///
    /// - parameter oid: Internal libgit2
    ///
    /// - returns: OID
    init(withGitOid oid: git_oid) {
        self.oid = oid
    }
    
    /// Init with git SHA
    ///
    /// - parameter sha: String containing SHA
    ///
    /// - throws: GitError
    ///
    /// - returns: OID
    public init(withSha sha: String?) throws {
        guard let sha = sha else {
            throw GitError.invalidSHA(sha: "nil")
        }
        if git_oid_fromstr(&self.oid, sha) != 0 {
            throw GitError.invalidSHA(sha: sha)
        }
    }
   
    /// Retrieve SHA string
    ///
    /// - returns: String containing SHA or nil
    public func sha() -> String? {
        
        // Create c_string
        var c_string = UnsafeMutablePointer<CChar>.allocate(capacity: 40)
        defer {
            c_string.deinitialize(count: 40)
            c_string.deallocate()
        }
        
        // Copy string
        var oid = self.oid
        git_oid_fmt(c_string, &oid)
        
        // Convert to string
        return String(bytesNoCopy: c_string, length: 40, encoding: String.Encoding.utf8, freeWhenDone: false)
    }
}
