//
//  Signature.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation
import Cgit2

/// Define a git signature
///
/// Wrap name and email
public class Signature {
    
    ///
    /// Signature name.
    ///
    public let name : String
    
    ///
    /// Signature mail.
    ///
    public let email : String
    
    /// Constructor with name and email
    ///
    /// - parameter name:  Signature name
    /// - parameter email: Signature email
    ///
    /// - returns: Signature
    public init(name: String, email: String) {
        self.name = name
        self.email = email
    }
    
    /// Constructor with libgit2 signature pointer
    ///
    /// - parameter sig: libgit2 signature
    ///
    /// - returns: Signature
    convenience init(sig : UnsafePointer<git_signature>) {
        self.init(name: git_string_converter(sig.pointee.name), email: git_string_converter(sig.pointee.email))
    }
    
    ///
    /// Create now signature.
    /// - Parameter sig : signature
    /// - Throws GitError
    ///
    
    /// Create libgit2 rsignature
    ///
    /// - parameter sig: Pointer where creating libgit2 signature
    ///
    /// - throws: GitError
    internal func now(sig : UnsafeMutablePointer<UnsafeMutablePointer<git_signature>?>) throws {
        let error = git_signature_now(sig, name, email)
        if (error != 0) {
            throw gitUnknownError("", code: error)
        }
    }
}
