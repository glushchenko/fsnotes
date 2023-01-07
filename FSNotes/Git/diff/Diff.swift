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
    var entries = Dictionary<String, DiffEntry>()
    
    init(_ diff: Diff) {
        self.diff = diff
    }
}

/// Diff
public class Diff {

    /// Internal Diff pointer
    internal let pointer : UnsafeMutablePointer<OpaquePointer?>
    
    /// All Diff entries
    lazy private var entries : NSMutableDictionary = {
        
        // Create internal object to convert in C pointer
        var payload = InternalDiffWrapper(self)
        
        // COnvert in C pointer
        let ptr = Unmanaged.passRetained(CWrapper(payload)).toOpaque()
        
        // Foreach on all diff entries
        let error = git_diff_foreach(self.pointer.pointee, gitDiffFileCB, nil, nil, nil, ptr)
        if (error != 0) {
            NSLog("Error login diff \(git_error_message())")
        }
        
        return paths
    } ()
    
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
    public func find(byPath path: String) -> DiffEntry? {
        paths.removeAllObjects()
        
        // Create internal object to convert in C pointer
        let payload = InternalDiffWrapper(self)
        
        // COnvert in C pointer
        let ptr = Unmanaged.passRetained(CWrapper(payload)).toOpaque()
        
        // Foreach on all diff entries
        let error = git_diff_foreach(self.pointer.pointee, gitDiffFileCB, nil, nil, nil, ptr)
        if (error != 0) {
            NSLog("Error login diff \(git_error_message())")
        }
        
        return paths[path] as? DiffEntry
    }
}



private func gitDiffFileCB(_ delta: UnsafePointer<git_diff_delta>?, progress:Float, payload: UnsafeMutableRawPointer?) ->Int32 {
    
    if let delta = delta {
        
        // Create diff entry
        let diffEntry = DiffEntry(delta: delta)
        
        // Test old name
        if let oldName = diffEntry.oldName {
            paths[oldName] = diffEntry
        }
        
        // Test new name
        if let newName = diffEntry.newName {
            paths[newName] = diffEntry
        }
    }
    
    
    return 0
}
