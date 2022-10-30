//
//  NSWindowController+.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 22.10.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

extension NSWindowController {
    public static var lastWindowSize: NSRect? = nil
    
    public func maximizeWindow() {
        let currentSize = window?.frame
        
        if let screen = NSScreen.main {
            let size = NSWindowController.lastWindowSize ?? screen.visibleFrame
            window?.setFrame(size, display: true, animate: true)

            if NSWindowController.lastWindowSize == nil {
                NSWindowController.lastWindowSize = currentSize
            } else {
                NSWindowController.lastWindowSize = nil
            }
        }
    }
}
