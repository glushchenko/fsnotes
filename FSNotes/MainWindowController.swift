//
//  MainWindowController.swift
//  FSNotes
//
//  Created by BUDDAx2 on 8/9/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import AppKit


class MainWindowController: NSWindowController,
NSWindowDelegate {
    
    func windowDidResize(_ notification: Notification) {
        let controller = NSApplication.shared().windows.first?.contentViewController as? ViewController
        controller?.refillEditArea()
    }
    
    override func windowDidLoad() {
        let appDelegate = NSApplication.shared().delegate as! AppDelegate
        appDelegate.mainWindowController = self
    }
    
    func makeNew() {
        window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
}
