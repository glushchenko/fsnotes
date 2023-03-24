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
    case uncommittedConflict
    
    func associatedValue() -> String {
        switch self {
        case .invalidSHA(sha: let sha):
            return "Invalid sha \(sha)"
        case .notFound(ref: let ref):
            return "Not found ref \(ref)"
        case .invalidSpec(spec: let spec):
            return "Invalid spec \(spec)"
        case .alreadyExists(ref: let ref):
            return "Already exist ref \(ref)"
        case .ambiguous(msg: let msg):
            return "Ambiguous \(msg)"
        case .invalidReference(msg: let msg, type: let type):
            return "Invalid ref \(msg) \(type)"
        case .unknownReference(msg: let msg):
            return "Unknown ref \(msg)"
        case .unknownError(msg: let msg, code: let code, desc: let desc):
            return "\(msg) \(code) \(desc)"
        case .unableToMerge(msg: let msg):
            return "Unable to merge \(msg)"
        case .modifiedElsewhere(ref: let ref):
            return "Modified error \(ref)"
        case .notImplemented(msg: let msg):
            return "Not implemented \(msg)"
        case .uncommittedConflict:
            return "Uncommitted conflict"
        }
    }
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
