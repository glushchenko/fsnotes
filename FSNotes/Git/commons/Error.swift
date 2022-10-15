//
//  Error.swift
//  Git2Swift
//
//  Created by Damien Giron on 31/07/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation
import Cgit2

public enum GitError : Error {
    
    case invalidSHA(sha: String)
    case notFound(ref: String)
    case invalidSpec(spec: String)
    case alreadyExists(ref: String)
    case ambiguous(msg: String)
    
    case invalidReference(msg: String, type: ReferenceType)
    case unknownReference(msg: String)
    case unknownError(msg: String, code: Int32, desc: String)
    case unableToMerge(msg: String)
    case modifiedElsewhere(ref: String)
    
    case notImplemented(msg: String)
}

func gitUnknownError(_ msg: String, code: Int32) -> GitError {
    return GitError.unknownError(msg: msg, code: code, desc: git_error_message())
}

///
/// Error message.
/// - Returns message.
///
func git_error_message() -> String {
    
    let error = giterr_last()
    if (error != nil) {
        return "\(String(cString: error!.pointee.message))"
    } else {
        return ""
    }
}
