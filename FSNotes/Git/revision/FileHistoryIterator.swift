//
//  FileRevLog.swift
//  Git2Swift
//
//  Created by Damien Giron on 14/09/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

import Cgit2

/// Iterate to file history
public class FileHistoryIterator: RevisionIterator {
    
    // File path
    private let path: String
    private let project: Project?
    
    // Previous commit oid
    private var previousOid: OID? = nil
    private var lastFetchedOid: OID? = nil
    
    public init(repository: Repository, path: String, refspec: String = "HEAD", project: Project? = nil) throws {
        self.project = project
        
        // Set path
        self.path = path
        
        // Create walker
        let walker = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Init walker
        var error = git_revwalk_new(walker, repository.pointer.pointee)
        guard error == 0 else {
            walker.deinitialize(count: 1)
            walker.deallocate()
            throw gitUnknownError("Unable to create rev walker for '\(refspec)'", code: error)
        }
        
        // Push reference
        error = git_revwalk_push_ref(walker.pointee, refspec)
        guard error == 0 else {
            walker.deinitialize(count: 1)
            walker.deallocate()
            throw gitUnknownError("Unable to set rev walker for '\(refspec)'", code: error)
        }
        
        super.init(repository: repository, pointer: walker)
    }
    
    
    /// Next value
    ///
    /// - returns: Next value or nil
    public override func next() -> OID? {
        
        guard let oid = super.next() else {
            return nil
        }
                
        lastFetchedOid = oid
        
        do {
            // Find commit
            let currentCommit = try repository.commitLookup(oid: oid)
            
            // Find parent entry
            let tree = try currentCommit.tree()
            
            // Find current entry
            let entry = try tree.entry(byPath: path)
            if (entry == nil) {
                return diffPrev(tree: tree, oid: oid)
            }
            
            // Test previous
            if (previousOid == nil) {
                previousOid = oid
                
                return next()
            } else {
                return diffPrev(tree: tree, oid: oid)
            }
            
        } catch {
            NSLog("Unable to find next OID \(error)")
        }
        
        return nil
    }
    
    public func walkCacheDiff() {
        var gitOid = git_oid()
        var oids = [OID]()

        while git_revwalk_next(&gitOid, pointer.pointee) == 0 {
            let oid = OID(withGitOid: gitOid)
            oids.append(oid)
        }

        for oid in oids {
            do {
                guard let pOid = previousOid else {
                    previousOid = oid
                    continue
                }

                let currentCommit = try repository.commitLookup(oid: oid)
                let tree = try currentCommit.tree()

                let previousCommit = try repository.commitLookup(oid: pOid)
                let previousTree = try previousCommit.tree()

                let diff = try previousTree.diff(other: tree)
                _ = diff.find(byPath: path, oid: oid, project: project)
            } catch {/*_*/}

            previousOid = oid
        }
    }
    
    private func diffPrev(tree: Tree, oid: OID) -> OID? {
        guard let pOid = previousOid else { return next() }
        
        do {
            // Find commit
            let previousCommit = try repository.commitLookup(oid: pOid)
            
            // Find parent entry
            let previousTree = try previousCommit.tree()
            
            // Find diff
            let diff = try previousTree.diff(other: tree)
            
            // Find
            if !diff.find(byPath: path, oid: oid, project: project) {
                
                // Set previous and find next
                previousOid = oid
                
                return next()
            } else {
                
                // Save previousOid
                let validOid = previousOid
                
                // Set previousOid
                previousOid = oid
                
                return validOid;
            }
        } catch {
            return nil
        }
    }
    
    public func getLast() -> OID? {
        return lastFetchedOid
    }
    
    public func checkFirstCommit() -> Bool {
        guard let oid = lastFetchedOid else { return false }
        
        do {
            let currentCommit = try repository.commitLookup(oid: oid)
            let tree = try currentCommit.tree()
            let entry = try tree.entry(byPath: path)
            if entry != nil {
                return true
            }
        } catch {/*_*/}
        
        return false
    }

    public func walk() -> [OID] {
        var gitOid = git_oid()
        var oids = [OID]()
        var oidsValid = [OID]()

        while git_revwalk_next(&gitOid, pointer.pointee) == 0 {
            let oid = OID(withGitOid: gitOid)
            oids.append(oid)
        }

        for oid in oids {
            if let oid = getMatchedOid(oid: oid) {
                oidsValid.append(oid)
            }
        }

        return oidsValid
    }

    public func getMatchedOid(oid: OID) -> OID? {
        lastFetchedOid = oid

        do {
            // Find commit
            let currentCommit = try repository.commitLookup(oid: oid)

            // Find parent entry
            let tree = try currentCommit.tree()

            // Find current entry
            let entry = try tree.entry(byPath: path)
            if (entry == nil) {
                return diff(tree: tree, oid: oid)
            }

            // Test previous
            if (previousOid == nil) {
                previousOid = oid

                return nil
            } else {
                return diff(tree: tree, oid: oid)
            }

        } catch {
            NSLog("Unable to find next OID \(error)")
        }

        return nil
    }

    private func diff(tree: Tree, oid: OID) -> OID? {
        guard let pOid = previousOid else { return nil }

        do {
            // Find commit
            let previousCommit = try repository.commitLookup(oid: pOid)

            // Find parent entry
            let previousTree = try previousCommit.tree()

            // Find diff
            let diff = try previousTree.diff(other: tree)

            // Find
            if !diff.find(byPath: path, oid: oid, project: project) {

                // Set previous and find next
                previousOid = oid

                return nil
            } else {

                // Save previousOid
                let validOid = previousOid

                // Set previousOid
                previousOid = oid

                return validOid;
            }
        } catch {
            return nil
        }
    }
}
