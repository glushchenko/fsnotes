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
    @IBAction func openInMenu(_ sender: Any) {
        let controller = NSApplication.shared().windows.first?.contentViewController as? ViewController
        
        let selected = controller?.notesTableView.getNoteFromSelectedRow()
        let fileUrl = selected?.url
        
        let defaultApp = UserDefaults.standard.object(forKey: "externalEditorApp")
        if (defaultApp != nil) {
            NSWorkspace.shared().openFile(fileUrl!.path, withApplication: defaultApp as? String)
        }
    }
    
    @IBAction func openInPreviewApp(_ sender: Any) {
        let controller = NSApplication.shared().windows.first?.contentViewController as? ViewController
        
        let selected = controller?.notesTableView.getNoteFromSelectedRow()
        let fileUrl = selected?.url
        
        let defaultApp = UserDefaults.standard.object(forKey: "previewApp")
        if (defaultApp != nil) {
            NSWorkspace.shared().openFile(fileUrl!.path, withApplication: defaultApp as? String)
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

