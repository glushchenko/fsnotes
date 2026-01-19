//
//  Tag.swift
//  Git2Swift
//
//  Created by Damien Giron on 12/08/2016.
//
//

import Foundation

/// Git tag
public class Tag : Object {
    
    /// Git2Swift repository
    public let repository : Repository
    
    /// Tag name, full path like "refs/tags/sample"
    public let name: String
    
    /// Short name like "sample"
    public let shortName: String
    
    /// Targeted OID
    public let oid: OID
    
    
    /// Constructor with name and OID
    ///
    /// - parameter repository: Git2Swift repository
    /// - parameter name:       tag name
    /// - parameter oid:        target OID
    ///
    /// - returns: Tag
    init(repository: Repository, name: String, oid: OID) {
        self.repository = repository
        self.name = "refs/tags/\(name)"
        self.shortName = name
        self.oid = oid
    }
    
    /// Rev tree
    ///
    /// - throws: GitError
    ///
    /// - returns: Tree
    public func revTree() throws -> Tree {
        return try git_revTree(repository: repository, referenceName: name)
    }
}
