//
//  Tags.swift
//  Git2Swift
//
//  Created by Damien Giron on 12/08/2016.
//
//

import Foundation
import Cgit2

// Manage tags
public class Tags {
    
    /// Git2Swift Repository
    public let repository: Repository
    
    /// Constructor with repository
    ///
    /// - parameter repository: Git2Swift repository
    ///
    /// - returns: Tags
    init(repository: Repository) {
        self.repository = repository
    }
    
    /// All tag names
    public func names() -> [String] {
        
        // Git array
        var tags = git_strarray()
        
        // List all tags
        git_tag_list(&tags, repository.pointer.pointee);
        
        // Convert to swift
        let strs = git_strarray_to_strings(&tags)
        
        // free array
        git_strarray_free(&tags)
        
        return strs
    }
    
    /// Get name
    ///
    /// - parameter name: tag name to search
    ///
    /// - throws: GitError
    ///
    /// - returns: Tag
    public func get(name: String) throws -> Tag {
        
        let spec : String
        let shortName : String
        
        // Find spec
        if (name.hasPrefix("refs/tags/")) {
            spec = name
            let startIndex = name.index(name.startIndex, offsetBy: 10)
            shortName = String(name[startIndex...])
        } else {
            spec = "refs/tags/\(name)"
            shortName = name
        }
        
        let reference = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Find tag reference
        let error = git_reference_lookup(reference, repository.pointer.pointee, spec)
        if (error != 0) {
            
            // 0 on success, GIT_ENOTFOUND, GIT_EINVALIDSPEC or an error code.
            switch error {
            case GIT_EINVALIDSPEC.rawValue:
                throw GitError.invalidSpec(spec: name)
            case GIT_ENOTFOUND.rawValue:
                throw GitError.notFound(ref: name)
            default:
                throw gitUnknownError("Unable to find tag", code: error)
                
            }
        }
        
        // Find git oid
        let gOid = git_tag_target_id(reference.pointee)
        if (gOid == nil) {
            throw GitError.notFound(ref: "refs/tags/\(name)")
        }
        
        return Tag(repository: repository, name: shortName, oid: OID(withGitOid: gOid!.pointee))
    }
    
    
    /// Create new tag
    ///
    /// - parameter name:  tag name
    /// - parameter force: force creation
    ///
    /// - throws: GitError
    ///
    /// - returns: new Tag
    public func create(name: String, force: Bool = false) throws -> Tag {
        
        // Tag oid
        var tag_oid = git_oid()
        
        // Create tag
        let error = git_tag_create_lightweight(&tag_oid, repository.pointer.pointee, name,
                                               try repository.head().targetCommit().pointer.pointee, force ? 1 : 0);
        if (error != 0) {
            switch error {
            case GIT_EEXISTS.rawValue :
                throw GitError.alreadyExists(ref: "refs/tags/\(name)")
            default:
                throw gitUnknownError("Unable to create tag", code: error)
            }
        }
        
        return Tag(repository: repository, name: name, oid: OID(withGitOid: tag_oid))
    }
    
    /// Remove tag by name
    ///
    /// - parameter name: tag name
    ///
    /// - throws: GitError
    public func remove(name: String) throws {
        let error = git_tag_delete(repository.pointer.pointee, name)
        if (error != 0) {
            throw gitUnknownError("Unable to delete tag", code: error)
        }
    }
    
    /// Find all tag in iterator
    ///
    /// - throws: GitError
    ///
    /// - returns: Tag iterator
    public func all() throws -> TagIterator {
        return try find()
    }
    
    /// Find tags
    ///
    /// - parameter pattern: tag pattern
    ///
    /// - throws: GitError
    ///
    /// - returns: TagIterator
    public func find(withPattern pattern: String? = nil) throws -> TagIterator {
        
        // Git array
        let tags = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
        
        if let pattern = pattern  {
            
            // List tags from pattern
            git_tag_list_match(tags, pattern, repository.pointer.pointee)
            
        } else {
            
            // List all tags
            git_tag_list(tags, repository.pointer.pointee);
            
        }
        
        // Return iterator form array
        return TagIterator(repository: repository, tagsArray: tags)
    }
}
