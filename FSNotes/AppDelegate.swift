//
//  AppDelegate.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/20/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import CloudKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindowController: MainWindowController?
    
    var appTitle: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return name ?? Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    }

    @IBAction func openHelp(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/glushchenko/fsnotes")!)
    }
    
    @IBAction func openMainWindow(_ sender: Any) {
        mainWindowController?.makeNew()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Ensure the font panel is closed when the app starts, in case it was
        // left open when the app quit.
        NSFontManager.shared.fontPanel(false)?.orderOut(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if UserDataService.instance.isShortcutCall {
            UserDataService.instance.isShortcutCall = false
            return
        }
        
        mainWindowController?.refreshEditArea()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if (!flag) {
            mainWindowController?.makeNew()
        } else {
            mainWindowController?.refreshEditArea()
        }
                
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            let name = url.lastPathComponent
            if let note = Storage.instance.getBy(title: name),
                let window = NSApplication.shared.windows.first,
                let controller = window.contentViewController as? ViewController {
                controller.updateTable(filter: name) {
                    controller.notesTableView.setSelected(note: note)
                }
            }
        }
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FSNotes")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }()
    
    #if CLOUDKIT
    func applicationWillFinishLaunching(_ notification: Notification) {
        if UserDefaultsManagement.cloudKitSync {
            NSApp.registerForRemoteNotifications(matching: NSApplication.RemoteNotificationType())
        }
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        if UserDefaultsManagement.cloudKitSync {
            let note: CKNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject])
            
            if note.notificationType == .query {
                CloudKitManager.sharedInstance().sync() {}
            }
        }
    }
    #endif
}
