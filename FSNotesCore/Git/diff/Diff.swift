//
//  Diff.swift
//  Git2Swift
//
//  Created by Damien Giron on 20/09/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

import Cgit2

var paths = NSMutableDictionary()


/// Define internal object to cast and use with C hander
class InternalDiffWrapper {
    
    /// Diff object
    var diff : Diff
    
    /// Entries parsed
    var entries = Dictionary<String, Bool>()
    
    init(_ diff: Diff) {
        self.diff = diff
    }
}

/// Diff
public class Diff {
    
    public static var commitsDict = ["sha": [String]()]

    /// Internal Diff pointer
    internal let pointer : UnsafeMutablePointer<OpaquePointer?>
    
    // Init with libgit2 diff pointer
    init(pointer: UnsafeMutablePointer<OpaquePointer?>) {
        self.pointer = pointer
    }
    
    deinit {
        if let ptr = pointer.pointee {
            git_diff_free(ptr)
        }
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }
    
    /// Find diff entry by path
    public func find(byPath path: String, oid: OID, project: Project? = nil) -> Bool {
        project?.loadCommitsCache()
        
        guard let sha = oid.sha() else { return false }
        paths.removeAllObjects()
        
        if let project = project, let paths = project.commitsCache[sha] {
            return paths.contains(path)
        }
        
        // Create internal object to convert in C pointer
        let payload = InternalDiffWrapper(self)
        
        // COnvert in C pointer
        let ptr = Unmanaged.passRetained(CWrapper(payload)).toOpaque()
        
        // Foreach on all diff entries
        let error = git_diff_foreach(self.pointer.pointee, DiffFile.callback, nil, nil, nil, ptr)
        if (error != 0) {
            NSLog("git diff error \(git_error_message())")
        }
        
        if let sha = oid.sha(), let keys = paths.allKeys as? [String], let project = project {
            project.commitsCache[sha] = keys
        }
        
        return paths[path] != nil
    }
}

final class DiffFile{
    static let callback: git_diff_file_cb = { delta, progress, payload in 
        if let delta = delta {
            
            // Create diff entry
            let diffEntry = DiffEntry(delta: delta)
            
            // Test old name
            if let oldName = diffEntry.oldName {
                paths[oldName] = true
            }
            
            // Test new name
            if let newName = diffEntry.newName {
                paths[newName] = true
            }
        }
        
        return 0
    }
}
