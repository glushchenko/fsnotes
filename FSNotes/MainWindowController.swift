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
    override func windowDidLoad() {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.mainWindowController = self
        self.window?.hidesOnDeactivate = UserDefaultsManagement.hideOnDeactivate
        self.window?.titleVisibility = .hidden
        self.window?.setFrameAutosaveName(NSWindow.FrameAutosaveName(rawValue: "MainWindow"))
    }
    
    func windowDidResize(_ notification: Notification) {
        refreshEditArea()
    }
    
    func windowDidDeminiaturize(_ notification: Notification) {
        refreshEditArea()
    }
    
    func makeNew() {
        window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
        refreshEditArea()
    }
    
    func refreshEditArea() {
        let controller = NSApplication.shared.windows.first?.contentViewController as? ViewController
        controller?.focusEditArea()
    }
}
