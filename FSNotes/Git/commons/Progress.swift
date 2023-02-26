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
public class Progress {
    
    public static var bufferedMessage: String?
    
    /// Progress
    ///
    /// - parameter current: Current entry
    /// - parameter total:   Total entry
    /// - parameter action:  action (transfert, checkout, ...)
    /// - parameter info:    info (Path, ...)
    func log(current: Int, total: Int, action: String) {
        #if os(iOS)
            DispatchQueue.main.async {
                let message = "git \(action): chunk \(current) from \(total)"
                Progress.bufferedMessage = message
                
                GitViewController.logTextField?.text = message
            }
        #endif
    }
    
    func log(message: String) {
        #if os(iOS)
            DispatchQueue.main.async {
                Progress.bufferedMessage = message
                
                GitViewController.logTextField?.text = message
            }
        #endif
        
        print("\(message)")
    }
}

final class ProgressDelegate {
    static let fetchProgressCallback: git_transfer_progress_cb = { stats, payload in
        if let stats = stats {
            AppDelegate.gitProgress.log(current: Int(stats.pointee.received_objects), total: Int(stats.pointee.total_objects), action: "fetch")
        }
        return 0
    }
    
    static let pushProgressCallback: git_push_transfer_progress_cb = { current, total, bytes, payload in
        AppDelegate.gitProgress.log(current: Int(current), total: Int(total), action: "push")
        return 0
    }
    
    static let packBuilderCallback: git_packbuilder_progress = { stage, current, total, payload in
        AppDelegate.gitProgress.log(current: Int(current), total: Int(total), action: "pack")
        return 0
    }

    static let checkoutProgressCallback: git_checkout_progress_cb = { path, completed, total, payload in
        AppDelegate.gitProgress.log(current: Int(completed), total: Int(total), action: "checkout")
    }
}
