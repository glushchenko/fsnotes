//
//  Strings.swift
//  Git2Swift
//
//  Created by Damien Giron on 31/07/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation
import Cgit2

/// Convert libgit2 string to Swift string
///
/// - parameter cStr: C string pointer
///
/// - returns: Swift string
func git_string_converter(_ cStr: UnsafePointer<CChar>) -> String {
    return String(cString: cStr)
}

/// Convert libgit2 string array to swift string array
///
/// - parameter strarray: libgit2 string array
///
/// - returns: String array
func git_strarray_to_strings(_ strarray: inout git_strarray) -> [String] {
    
    var strs = [String]()
    
    let count = strarray.count
    if (count == 0) {
        return strs
    }
    
    strs.reserveCapacity(count)
    for i in 0...(count - 1) {
        strs.append(String(cString: strarray.strings[i]!))
    }
    return strs
}


///
/// Define a string wrapper used to transform a String array to pointer array.
///
class StringWrapper {
    
    ///
    /// Raw UTF-8
    ///
    private var rawUtf8 = [ContiguousArray<Int8>]()
    
    ///
    /// Character count.
    ///
    let count : Int
    
    ///
    /// Pointer to 'const char **'
    ///
    private(set) var pointer : UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
    
    ///
    /// Init string wrapper.
    /// - Parameter strs : String array.
    ///
    init(withStrs strs: [String]) {
        
        // String count
        count = strs.count
        
        // Create result
        pointer = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: count)
        
        // Store raw utf8
        rawUtf8.reserveCapacity(count)
        
        // Init iterator
        var iterator = pointer
        
        // Iterate other strings
        for str in strs {
            
            // Create utf8 cString
            let cStr : ContiguousArray<Int8> = str.utf8CString
            rawUtf8.append(cStr)
            
            // Set pointer
            let cStr1 = cStr.withUnsafeBufferPointer { UnsafeMutablePointer<Int8>(mutating: $0.baseAddress) }
            
            // Initialize with utf8 data
            iterator.initialize(to: cStr1)
            
            // Add successor
            iterator = iterator.successor()
        }
    }
    
    deinit {
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }
}
