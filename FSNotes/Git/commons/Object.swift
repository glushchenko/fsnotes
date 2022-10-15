//
//  Object.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation

/// Object
public protocol Object {
    
    /// Oid
    var oid : OID { get }
}
