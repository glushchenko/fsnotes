//
//  PrefsWindowController.swift
//  FSNotes
//
//  Created by Jeff Hanbury on 13/08/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PrefsWindowController: NSWindowController, NSWindowDelegate {

    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.delegate = self
        self.window?.title = "Preferences"
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // If the Font Panel was open, show it again.
        let controller = self.contentViewController as! PrefsViewController

        if let ui = controller.children[1] as? PreferencesUserInterfaceViewController, ui.fontPanelOpen {

            NSFontManager.shared.orderFrontFontPanel(self)
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // If the Font Panel is open, hide it.
        let controller = self.contentViewController as! PrefsViewController

        if let ui = controller.children[1] as? PreferencesUserInterfaceViewController, ui.fontPanelOpen {
            NSFontManager.shared.fontPanel(false)?.orderOut(self)
        }
    }
    
}
