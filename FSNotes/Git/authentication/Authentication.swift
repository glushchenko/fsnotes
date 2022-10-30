//
//  Authentication.swift
//  Git2Swift
//
//  Created by Damien Giron on 20/08/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

import Cgit2

/// Authentication handler
public protocol AuthenticationHandler {
    
    /// Raw libgit2 authentication
    ///
    /// - parameter out:      Git credential
    /// - parameter url:      url
    /// - parameter username: username
    ///
    /// - returns: 0 on ok
    func authenticate(out: UnsafeMutablePointer<UnsafeMutablePointer<git_cred>?>?,
                      url: String?,
                      username: String?) -> Int32
}



func setAuthenticationCallback(_ callbacksStruct: inout git_remote_callbacks,
                               authentication: AuthenticationHandler?) {
    
    // Convert handler to payload pointer
    callbacksStruct.payload = Unmanaged
        .passRetained(CWrapper(authentication))
        .toOpaque()
    
    // Create crdential lambda calling credential handler
    callbacksStruct.credentials = { out, url, username_from_url, allowed_types, payload in
        
        // Find url
        let sUrl : String?
        if (url == nil) {
            sUrl = nil
        } else {
            sUrl = git_string_converter(url!)
        }
        
        // Find username_from_url
        let userName : String?
        if (username_from_url == nil) {
            userName = nil
        } else {
            userName = git_string_converter(username_from_url!)
        }
        
        // Transformation du pointer en wrapper
        let authenticationWrapper = Unmanaged<CWrapper<AuthenticationHandler>>
            .fromOpaque(payload!)
            .takeRetainedValue()
        let result = authenticationWrapper.object.authenticate(out: out,
                                                               url: sUrl,
                                                               username: userName)
        
        return result
    }
}
