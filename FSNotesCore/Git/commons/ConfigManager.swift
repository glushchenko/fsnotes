//
//  ConfigManager.swift
//  Git2Swift
//
//  Created by Damien Giron on 01/08/2016.
//
//

import Foundation
import Cgit2

/// Config manager
public class ConfigManager {
    
    /// LibGit2 config pointer
    private let cfg : UnsafeMutablePointer<OpaquePointer?>
    
    /// Constructor
    ///
    /// - throws: GitError
    ///
    /// - returns: ConfigManager
    init() throws {
        
        // Config
        cfg = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        
        // Read config
        let error = git_config_open_default(cfg);
        if (error != 0) {
            throw gitUnknownError("Unable to open config", code: error)
        }
    }
    
    deinit {
        if let ptr = cfg.pointee {
            git_config_free(ptr)
        }
        cfg.deinitialize(count: 1)
        cfg.deallocate()
    }
    
    /// Read string
    ///
    /// - parameter key: Key value
    ///
    /// - throws: GitError wrapping libgit2 error
    ///
    /// - returns: String
    public func readString(key: String) throws -> String {
        
        // email entry
        let entry = UnsafeMutablePointer<UnsafeMutablePointer<git_config_entry>?>.allocate(capacity: 1)
        defer {
            if (entry.pointee != nil) {
                git_config_entry_free(entry.pointee)
            }
            entry.deinitialize(count: 1)
            entry.deallocate()
        }
        
        let value : String
        if git_config_get_entry(entry, cfg.pointee, key) == 0 {
            value = String(cString: entry.pointee!.pointee.value)
        } else {
            value = String("")
        }
        
        return value
    }
    
}
