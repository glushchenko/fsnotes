//
//  Status.swift
//  Git2Swift
//
//  Created by Damien Giron on 12/08/2016.
//
//

import Foundation
import Cgit2

/// Define status types
///
/// - current:         Todo
/// - indexNew:        New file in index
/// - indexModified:   Modified file in index
/// - indexDeleted:    Deleted file in index
/// - indexRenamed:    Renamed file in index
/// - indexTypeChange: Todo
/// - wtNew:           New file in working directory
/// - wtModified:      Modified file in working directory
/// - wtDeleted:       Deleted file in working directory
/// - wtTypeChange:    Todo
/// - wtRenamed:       Renamed file in working directory
/// - wtUnreadable:    Unreadable file in working directory
/// - ignored:         Ignored file
/// - conflicted:      Conflicted file
public enum StatusType : UInt32 {
    
    case current = 0
    
    case indexNew        = 1
    case indexModified   = 2
    case indexDeleted    = 4
    case indexRenamed    = 8
    case indexTypeChange = 16
    
    case wtNew           = 128
    case wtModified      = 256
    case wtDeleted       = 512
    case wtTypeChange    = 1024
    case wtRenamed       = 2048
    case wtUnreadable    = 4096
    
    case ignored          = 16384
    case conflicted       = 32768
    
}

/// Define a file status
public class Status {
    
    /// File path
    public let path : String
    
    /// Status type
    public let type : StatusType
    
    /// Init with libgit2 status entry
    ///
    /// - parameter entry: Libgit2 status entry pointer
    ///
    /// - throws: GitError with libgit2 error
    ///
    /// - returns: Status
    init(entry: UnsafePointer<git_status_entry>) throws {
        
        // Test index
        if (entry.pointee.index_to_workdir != nil) {
            path = String(cString: entry.pointee.index_to_workdir.pointee.new_file.path!)
        }
            
        else if (entry.pointee.head_to_index != nil) {
            path = String(cString: entry.pointee.head_to_index.pointee.new_file.path!)
        }
            
        else {
            path = "<Error>"
        }
        
        guard let type = StatusType(rawValue: entry.pointee.status.rawValue) else {
            throw GitError.unknownError(msg: "Unable to init status", code: -1, desc: "Unable to find status \(entry.pointee.status)")
        }
        
        // Set status
        self.type = type
    }
}
