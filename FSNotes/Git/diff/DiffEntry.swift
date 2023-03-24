//
//  DiffEntry.swift
//  Git2Swift
//
//  Created by Damien Giron on 21/09/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

import Cgit2

/// Delta type
///
/// - unmodified: no changes
/// - added:      entry does not exist in old version
/// - deleted:    entry does not exist in new version
/// - modified:   entry content changed between old and new
/// - renamed:    entry was renamed between old and new
/// - copied:     entry was copied from another old entry
/// - ignored:    entry is ignored item in workdir
/// - untracked:  entry is untracked item in workdir
/// - typechange: type of entry changed between old and new
/// - unreadable: entry is unreadable
/// - conflicted: entry in the index is conflicted
/// - unknown:    Enum size
public enum DeltaType : UInt32 {
    case unmodified = 0
    case added = 1
    case deleted = 2
    case modified = 3
    case renamed = 4
    case copied = 5
    case ignored = 6
    case untracked = 7
    case typechange = 8
    case unreadable = 9
    case conflicted = 10
    case unknown
}

/// Diff entry
public class DiffEntry {
    
    /// Old file name
    public let oldName : String?
    
    /// New file name
    public let newName : String?
    
    /// Delta entry type
    public let type : DeltaType
    
    init(delta: UnsafePointer<git_diff_delta>) {
        
        let ptr = delta.pointee
        
        oldName = git_string_converter(ptr.old_file.path)
        newName = git_string_converter(ptr.old_file.path)
        if let type = DeltaType(rawValue: ptr.status.rawValue) {
            self.type = type
        } else {
            self.type = .unknown
        }
    }
}

public class DiffFileNew {
    init(delta: UnsafePointer<git_diff_file>) {
        let ptr = delta.pointee
        print(git_string_converter(ptr.path))
    }
}
