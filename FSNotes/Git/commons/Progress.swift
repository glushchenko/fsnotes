//
//  Progress.swift
//  Git2Swift
//
//  Created by Dami on 24/09/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation

import Cgit2

/// Define progress protocol
public class Progress : Any {
    
    /// Progress
    ///
    /// - parameter current: Current entry
    /// - parameter total:   Total entry
    /// - parameter action:  action (transfert, checkout, ...)
    /// - parameter info:    info (Path, ...)
    func progress(current: Int, total: Int, action: String?, info: String?) {
        NSLog(" - \(current) / \(total) -> \(action) : \(info)")
    }
}

/// Set transfert handler
///
/// - parameter options:  git_remote_callbacks
/// - parameter progress: Progress may be nil
func setTransfertProgressHandler(options: inout git_remote_callbacks, progress: Progress?) {
    
    if let progress = progress {
        
        // Convert handler to payload pointer
        options.payload = Unmanaged<Progress>
            .passUnretained(progress)
            .toOpaque()
        
        // Create lambda
        options.transfer_progress = { stats, payload in
            
            // Find payload
            if let payload = payload {
                
                // Transformation du pointer en wrapper
                let progress = Unmanaged<Progress>
                    .fromOpaque(payload)
                    .takeUnretainedValue()
                
                if let stats = stats {
                    // Call handler
                    progress.progress(current: Int(stats.pointee.received_objects),
                                      total: Int(stats.pointee.total_objects),
                                      action: "transfert",
                                      info: nil)
                }
            }
            
            
            return 0
        }
    }
}

/// Set checkout handler
///
/// - parameter options:  git_checkout_options
/// - parameter progress: Progress may be nil
func setCheckoutProgressHandler(options: inout git_checkout_options, progress: Progress?) {
    
    if let progress = progress {
        
        // Convert handler to payload pointer
        options.progress_payload = Unmanaged<Progress>
            .passUnretained(progress)
            .toOpaque()
        
        // Create lambda
        options.progress_cb = { path, cur, tot, payload in
            
            // Find payload
            if let payload = payload {
                
                // Transformation du pointer en wrapper
                let progress = Unmanaged<Progress>
                    .fromOpaque(payload)
                    .takeUnretainedValue()
                
                // Call handler
                progress.progress(current: cur,
                                  total: tot,
                                  action: "transfert",
                                  info: path == nil ? nil : git_string_converter(path!))
            }
        }

    }
}
