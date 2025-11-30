//
//  Wrapper.swift
//  Git2Swift
//
//  Created by Damien Giron on 20/09/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

/// Wrap authentication to C function
internal class CWrapper<T> {
    
    /// Object
    let object: T
    
    /// Init wrapper
    ///
    /// - parameter object: Wrapper
    ///
    /// - returns: Wrapper
    init(_ object: T) {
        self.object = object
    }
}
