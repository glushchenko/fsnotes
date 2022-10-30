//
//  TreeEntry.swift
//  Git2Swift
//
//  Created by Damien Giron on 20/09/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

import Cgit2

/// Tree entry
public class TreeEntry {

    /// The filename of a tree entry
    public let name : String
    
    /// Libgit2 pointer
    internal let pointer : UnsafeMutablePointer<OpaquePointer?>
    
    init(pointer: UnsafeMutablePointer<OpaquePointer?>) {
        self.pointer = pointer
        
        self.name = git_string_converter(git_tree_entry_name(pointer.pointee))
    }
    
    deinit {
        if let ptr = pointer.pointee {
            git_tree_entry_free(ptr)
        }
        
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }
}
