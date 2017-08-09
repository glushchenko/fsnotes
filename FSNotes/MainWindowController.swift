//
//  MainWindowController.swift
//  FSNotes
//
//  Created by BUDDAx2 on 8/9/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import AppKit


class MainWindowController: NSWindowController {
    
    override func windowDidLoad() {
        
        let appDelegate = NSApplication.shared().delegate as! AppDelegate
        appDelegate.mainWindowController = self
    }
    
    
    func activateMainWindow() {
        
        self.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
}
