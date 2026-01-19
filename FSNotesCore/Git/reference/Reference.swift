//
//  Reference.swift
//  Git2Swift
//
//  Created by Dami on 31/07/2016.
//
//

import Foundation
import Cgit2

/// Refrence type
///
/// - invalid:  Invalid reference
/// - oid:      Reference OID
/// - symbolic: Reference an other reference
public enum ReferenceType {
    case invalid
    case oid
    case symbolic
}

/// Git2Swift reference type from libgit2
///
/// - parameter type: libgit2 type
///
/// - returns: Swift2Git type
func git_reference_type(_ type: git_reference_t) -> ReferenceType {
    switch type.rawValue {
    case GIT_REFERENCE_DIRECT.rawValue :
        return .oid
    case GIT_REFERENCE_SYMBOLIC.rawValue:
        return .symbolic
    default:
        return .invalid
    }
}

/// Fonction to retrieve tree from refrence
///
/// - parameter repository:    Git2Swift repository
/// - parameter referenceName: Reference name
///
/// - throws: GitError
///
/// - returns: Git2Swift tree
func git_revTree(repository: Repository, referenceName: String) throws -> Tree {
    
    // Find branch tree
    let revTree = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    
    // Find tree
    let error = git_revparse_single(revTree, repository.pointer.pointee, referenceName);
    if (error != 0) {
        throw gitUnknownError("Unable to find rev-tree for '\(referenceName)'", code: error)
    }
    
    return Tree(repository: repository, tree: revTree)
}

/// Git2Swift reference
public class Reference {
    
    /// Reference name
    public let name : String
    
    /// Git2Swift reference type
    public let refType : ReferenceType
    
    /// Git2Swift Repository
    public let repository : Repository
    
    /// Libgit2 refrence pointer
    internal let pointer : UnsafeMutablePointer<OpaquePointer?>
    
    /// Target reference
    ///
    /// - throws: GitError
    ///
    /// - returns: Swift2Git refrence
    public func targetReference() throws -> Reference {
        switch refType {
        case .symbolic:
            return try repository.referenceLookup(name: git_string_converter(git_reference_symbolic_target(pointer.pointee)))
        case .oid:
            throw GitError.invalidReference(msg: "Unable to dereference symbolic target", type: .symbolic)
        default:
            throw GitError.unknownReference(msg: "Unable to dereference symbolic target")
        }
    }
    
    /// Find rev tree
    ///
    /// - throws: GitError
    ///
    /// - returns: Tree
    public func revTree() throws -> Tree {
        return try git_revTree(repository: repository, referenceName: name)
    }
    
    /// Create revision walker from this reference
    ///
    /// - throws: GitError
    ///
    /// - returns: Revision walker
    public func revWalker() throws -> RevisionIterator {
        
        // Create walker
        let walker = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Init walker
        var error = git_revwalk_new(walker, repository.pointer.pointee)
        guard error == 0 else {
            walker.deinitialize(count: 1)
            walker.deallocate()
            throw gitUnknownError("Unable to create rev walker for \(name)", code: error)
        }
        
        // Push reference
        error = git_revwalk_push_ref(walker.pointee, name)
        guard error == 0 else {
            walker.deinitialize(count: 1)
            walker.deallocate()
            throw gitUnknownError("Unable to set rev walker for \(name)", code: error)
        }
        
        return RevisionIterator(repository: repository, pointer: walker)
    }
    
    /// Constructor with repository, name and pointer
    ///
    /// - parameter repository: Git2Swift repository
    /// - parameter name:       Reference name
    /// - parameter pointer:    libgit2 reference pointer
    ///
    /// - throws: GitError
    ///
    /// - returns: Git2Swift reference
    init(repository: Repository, name: String, pointer: UnsafeMutablePointer<OpaquePointer?>) throws {
        self.repository = repository
        self.pointer = pointer
        self.name = git_string_converter(git_reference_name(pointer.pointee))
        self.refType = git_reference_type(git_reference_type(pointer.pointee))
    }

    /// Constructor with repository and pointer
    ///
    /// - parameter repository: Git2Swift repository
    /// - parameter pointer:    libgit2 reference pointer
    ///
    /// - throws: GitError
    ///
    /// - returns: Git2Swift reference
    convenience init(repository: Repository, pointer: UnsafeMutablePointer<OpaquePointer?>) throws {
        // Finde name
        let str = git_reference_name(pointer.pointee)
        guard let name = str else {
            throw GitError.notFound(ref: "Unknown")
        }
        try self.init(repository: repository, name: git_string_converter(name), pointer: pointer)
    }
    
    deinit {
        if let ptr = pointer.pointee {
            git_reference_free(ptr)
        }
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }
}
