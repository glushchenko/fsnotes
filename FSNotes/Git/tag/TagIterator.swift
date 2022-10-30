//
//  TagIterator.swift
//  Git2Swift
//
//  Created by Damien Giron on 12/08/2016.
//
//

import Foundation
import Cgit2

/// Tag iterator
public class TagIterator {
    
    /// Current array index
    private var index = 0
    
    /// Git2Swift repository
    private let repository : Repository
    
    /// Arrays of tags pointer
    private var tagsArray :  UnsafeMutablePointer<git_strarray>

    /// Constructor with Git2Swift and libgit2 array pointer
    ///
    /// - parameter repository: Git2Swift repository
    /// - parameter tagsArray:  Libgit2 array pointer
    ///
    /// - returns: Tag iterator
    init(repository: Repository, tagsArray: UnsafeMutablePointer<git_strarray>) {
        self.repository = repository
        self.tagsArray = tagsArray
    }
    
    deinit {
        git_strarray_free(tagsArray)
        tagsArray.deinitialize(count: 1)
        tagsArray.deallocate()
    }
    
    /// Find next tag
    ///
    /// - returns: Next tag or nil
    public func next() -> Tag? {
        if (index < tagsArray.pointee.count) {
            let tag = try? repository.tags.get(name: String(cString: tagsArray.pointee.strings[index]!))
            if (tag == nil) {
                return nil
            }
            index += 1
            return tag
        } else {
            return nil
        }
    }
}
