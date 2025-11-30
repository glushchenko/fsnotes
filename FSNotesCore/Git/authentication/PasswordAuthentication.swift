//
//  PasswordAuthentication.swift
//  Git2Swift
//
//  Created by Damien Giron on 11/09/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

import Cgit2

public protocol PasswordData {
    var username : String? {
        get
    }
    var password : String? {
        get
    }
}

public struct RawPasswordData : PasswordData {
    public let username : String?
    public let password : String?
    
    public init(username : String?, password : String?) {
        self.username = username
        self.password = password
    }
}

/// Password delegate
public protocol PasswordDelegate {
    
    /// Get password data
    ///
    /// - parameter username: username
    /// - parameter url:      url
    ///
    /// - returns: Password data
    func get(username: String?, url: URL?) -> PasswordData
}

/// Password handler
public class PasswordHandler : AuthenticationHandler {
    
    /// Password delegate
    private let passwordDelegate : PasswordDelegate
    
    public init(passwordDelegate: PasswordDelegate) {
        self.passwordDelegate = passwordDelegate
    }
    
    /// Authentication
    ///
    /// - parameter out:      Git credential
    /// - parameter url:      url
    /// - parameter username: user name
    ///
    /// - returns: 0 on ok
    public func authenticate(out: UnsafeMutablePointer<UnsafeMutablePointer<git_cred>?>?,
                             url: String?,
                             username: String?) -> Int32 {
        
        // Find password data
        let passwordData = passwordDelegate.get(username: username, url: url == nil ? nil : URL(string: url!))
        
        let optionalUsername = passwordData.username
        let optionalPasword = passwordData.password
        
        // Auth plain text
        return git_cred_userpass_plaintext_new(
            out,
            optionalUsername == nil ? "" : optionalUsername!,
            optionalPasword == nil ? "" : optionalPasword!)
    }
}
