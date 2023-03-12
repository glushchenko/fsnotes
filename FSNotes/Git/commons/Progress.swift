//
//  Progress.swift
//  Git2Swift
//
//  Created by Dami on 24/09/2016.
//  Copyright © 2016 Creabox. All rights reserved.
//

import Foundation
import Cgit2

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Define progress protocol
public class GitProgress {
    public var project: Project

#if os(iOS)
    public var statusTextField: UITextField
    
    init(statusTextField: UITextField, project: Project) {
        self.statusTextField = statusTextField
        self.project = project
    }
#else
    public var statusTextField: NSTextField

    init(statusTextField: NSTextField, project: Project) {
        self.statusTextField = statusTextField
        self.project = project
    }
#endif
    
    func log(current: Int, total: Int, action: String) {
        let message = "git \(action): chunk \(current) from \(total)"
        project.gitStatus = message

        #if os(iOS)
            DispatchQueue.main.async {
                self.statusTextField.text = message
            }
        #endif
    }
    
    func log(message: String) {
        project.gitStatus = message

        #if os(iOS)
            DispatchQueue.main.async {
                self.statusTextField.text = message
            }
        #endif
        
        print("\(message)")
    }
}

final class ProgressDelegate {
    static let fetchProgressCallback: git_transfer_progress_cb = { stats, payload in
        if let stats = stats {
            AppDelegate.gitProgress?.log(current: Int(stats.pointee.received_objects), total: Int(stats.pointee.total_objects), action: "fetch")
        }
        return 0
    }
    
    static let pushProgressCallback: git_push_transfer_progress_cb = { current, total, bytes, payload in
        AppDelegate.gitProgress?.log(current: Int(current), total: Int(total), action: "push")
        return 0
    }
    
    static let packBuilderCallback: git_packbuilder_progress = { stage, current, total, payload in
        AppDelegate.gitProgress?.log(current: Int(current), total: Int(total), action: "pack")
        return 0
    }

    static let checkoutProgressCallback: git_checkout_progress_cb = { path, completed, total, payload in
        AppDelegate.gitProgress?.log(current: Int(completed), total: Int(total), action: "checkout")
    }
}
