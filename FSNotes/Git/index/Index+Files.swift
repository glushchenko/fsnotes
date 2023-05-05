//
//  Index+Files.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation
import Cgit2

///
/// Find relative path to an other url.
///
func relativePath(from: URL, to: URL) -> String? {
    
    // Find current file path
    let currentFilePath = from.absoluteURL.path
    
    // Find from path
    let fromFilePath = to.path
    
    // Check if current URL is parent of from
    guard (currentFilePath.hasPrefix(fromFilePath)) else {
        return nil
    }
    
    // Find prefix size
    let size = fromFilePath.count + (currentFilePath[currentFilePath.startIndex] == "/" ? 1 : 0 )
    
    // Return sub string
    return currentFilePath.substring(from: currentFilePath.index(currentFilePath.startIndex, offsetBy: size))
}

// MARK: - Index extension for files
extension Index {
    
    /// Add item
    ///
    /// - parameter url: URL of the item
    ///
    /// - throws: GitError
    public func addItem(at url: URL) throws {
        
        // Create relative path
        guard let path = relativePath(from: url, to: repository.url) else {
            throw GitError.notFound(ref: url.absoluteString)
        }
        
        let error = git_index_add_bypath(idx.pointee, path);
        if (error != 0) {
            throw gitUnknownError("Unable to add item to index", code: error)
        }
    }
    
    /// Add item
    ///
    /// - parameter url: URL of the item
    ///
    /// - throws: GitError
    public func addItem(data: Data, at path: String) throws {
        var index_entry = git_index_entry()
        try path.withCString { (ptr: UnsafePointer<Int8>) -> Void in
            index_entry.path = ptr
            index_entry.mode = 33188
            /* create a blob from our buffer */
            try data.withUnsafeBytes {(bytes: UnsafePointer<OpaquePointer?>) -> Void in
                let error = git_index_add_frombuffer(idx.pointee, &index_entry, bytes, data.count)
                if error != 0 {
                    throw gitUnknownError("Unable to add Data to index", code: error)
                }
            }
        }
    }
    
    /// Remove item
    ///
    /// - parameter url: URL of the item
    ///
    /// - throws: GitError
    public func removeItem(at url: URL) throws {
        
        // Create relative path
        guard let path = relativePath(from: url, to: repository.url) else {
            throw GitError.notFound(ref: url.absoluteString)
        }
        
        let error = git_index_remove_bypath(idx.pointee, path)
        if (error != 0) {
            throw gitUnknownError("Unable to remove item to index", code: error)
        }
    }
    
    /// Save index
    ///
    /// - throws: GitError
    public func save() throws {
        let error = git_index_write(idx.pointee)
        if (error != 0) {
            throw gitUnknownError("Unable to save index", code: error)
        }
    }
    
    /// Reload index
    ///
    /// - throws: GitError
    public func reload() throws {
        let error = git_index_read(idx.pointee, 1); // A for true
        if (error != 0) {
            throw gitUnknownError("Unable to read index", code: error)
        }
    }
    
    /// Clear index
    ///
    /// - throws: GitError
    public func clear() throws {
        let error = git_index_clear(idx.pointee);
        if (error != 0) {
            throw gitUnknownError("Unable to read index", code: error)
        }
    }

    static var count = 0

    static let gitIndexCallback: git_index_matched_path_cb = { path, match, payload in
        let newPath: String = git_string_converter(path!)

        if newPath.startsWith(string: ".Trash") {
            return 1
        }

        count += 1
        return 0
    }
    
    public func add(path: String) -> Bool {
        var dirPointer = UnsafeMutablePointer<Int8>(mutating: (path as NSString).utf8String)
        var paths = withUnsafeMutablePointer(to: &dirPointer) {
            git_strarray(strings: $0, count: 1)
        }
        
        idx.pointee.flatMap { index in
            defer { git_index_free(index) }
            let addResult = git_index_add_all(index, &paths, 0, Index.gitIndexCallback, nil)
            guard addResult == GIT_OK.rawValue else {
                print("git_index_add_all \(addResult)")
                return
            }
            // write index to disk
            let writeResult = git_index_write(index)
            guard writeResult == GIT_OK.rawValue else {
                print("git_index_write \(writeResult)")
                return
            }
        }

        let success = Index.count > 0

        // reset
        Index.count = 0

        return success
    }
}
