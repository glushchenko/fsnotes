//
//  AppDelegate.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/20/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var mainWindowController: MainWindowController?
    
    @IBAction func openInMenu(_ sender: Any) {
        let controller = NSApplication.shared().windows.first?.contentViewController as? ViewController
        
        let selected = controller?.notesTableView.getNoteFromSelectedRow()
        let fileUrl = selected?.url
        
        NSWorkspace.shared().openFile(fileUrl!.path, withApplication: UserDefaultsManagement.externalEditor)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Ensure the font panel is closed when the app starts, in case it was
        // left open when the app quit.
        NSFontManager.shared().fontPanel(false)?.orderOut(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {

        mainWindowController?.activateMainWindow()

        return true
    }
}

