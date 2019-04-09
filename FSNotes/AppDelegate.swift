//
//  AppDelegate.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/20/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import FSNotesCore_macOS

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    var mainWindowController: MainWindowController?
    var prefsWindowController: PrefsWindowController?
    var statusItem: NSStatusItem?
    
    var appTitle: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return name ?? Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        if UserDefaultsManagement.showInMenuBar {
            constructMenu()
        }
        
        if !UserDefaultsManagement.showDockIcon {
            let transformState = ProcessApplicationTransformState(kProcessTransformToUIElementApplication)
            var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
            TransformProcessType(&psn, transformState)

            NSApp.setActivationPolicy(.accessory)
        }

        let storage = Storage.sharedInstance()
        storage.loadDocuments() {}
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Ensure the font panel is closed when the app starts, in case it was
        // left open when the app quit.
        NSFontManager.shared.fontPanel(false)?.orderOut(self)

        applyAppearance()

        #if CLOUDKIT
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            
            if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
                do {
                    try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Home directory creation: \(error)")
                }
            }
        }
        #endif

        if UserDefaultsManagement.storagePath == nil {
            self.requestStorageDirectory()
            return
        }
        
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        
        guard let mainWC = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "MainWindowController")) as? MainWindowController else {
            fatalError("Error getting main window controller")
        }
        
        self.mainWindowController = mainWC
        mainWC.window?.makeKeyAndOrderFront(nil)
    }
        
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if (!flag) {
            mainWindowController?.makeNew()
        } else {
            mainWindowController?.refreshEditArea()
        }
                
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        let webkitPreview = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wkPreview")

        try? FileManager.default.removeItem(at: webkitPreview)

        let encryption = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Encryption")
        try? FileManager.default.removeItem(at: encryption)
    }
    
    private func applyAppearance() {
        
        if #available(OSX 10.14, *) {
            if UserDefaultsManagement.appearanceType != .Custom {
                if UserDefaultsManagement.appearanceType == .Dark {
                    NSApp.appearance = NSAppearance.init(named: NSAppearance.Name.darkAqua)
                    UserDataService.instance.isDark = true
                }
                
                if UserDefaultsManagement.appearanceType == .Light {
                    NSApp.appearance = NSAppearance.init(named: NSAppearance.Name.aqua)
                    UserDataService.instance.isDark = false
                }
                
                if UserDefaultsManagement.appearanceType == .System, NSAppearance.current.isDark {
                    UserDataService.instance.isDark = true
                }
            } else {
                NSApp.appearance = NSAppearance.init(named: NSAppearance.Name.aqua)
            }
        }
    }
    
    private func restartApp() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        
        let url = URL(fileURLWithPath: resourcePath)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        
        exit(0)
    }
    
    private func requestStorageDirectory() {
        var directoryURL: URL? = nil
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            directoryURL = URL(fileURLWithPath: path)
        }
        
        let panel = NSOpenPanel()
        panel.directoryURL = directoryURL
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Please select default storage directory"
        panel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                guard let url = panel.url else {
                    return
                }
                
                let bookmarks = SandboxBookmark.sharedInstance()
                bookmarks.save(url: url)
                
                UserDefaultsManagement.storagePath = url.path
                
                self.restartApp()
            } else {
                exit(EXIT_SUCCESS)
            }
        }
    }
    
    func constructMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button, let image = NSImage(named: NSImage.Name(rawValue: "blackWhite")) {
            image.size.width = 20
            image.size.height = 20
            button.image = image
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: NSLocalizedString("New", comment: ""), action: #selector(AppDelegate.new(_:)), keyEquivalent: "n"))
        
        let rtf = NSMenuItem(title: NSLocalizedString("New RTF", comment: ""), action: #selector(AppDelegate.newRTF(_:)), keyEquivalent: "n")
        var modifier = NSEvent.modifierFlags
        modifier.insert(.command)
        modifier.insert(.shift)
        rtf.keyEquivalentModifierMask = modifier
        menu.addItem(rtf)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("Search and create", comment: ""), action: #selector(AppDelegate.searchAndCreate(_:)), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: NSLocalizedString("Preferences", comment: ""), action: #selector(AppDelegate.openPreferences(_:)), keyEquivalent: ","))

        let lock = NSMenuItem(title: NSLocalizedString("Lock All Encrypted", comment: ""), action: #selector(ViewController.shared()?.lockAll(_:)), keyEquivalent: "l")
        lock.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(lock)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit FSNotes", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        menu.delegate = self
        statusItem?.menu = menu
    }
    
    // MARK: IBActions
    
    @IBAction func openMainWindow(_ sender: Any) {
        mainWindowController?.makeNew()
    }
    
    @IBAction func openHelp(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/glushchenko/fsnotes")!)
    }
    
    @IBAction func openPreferences(_ sender: Any?) {
        if prefsWindowController == nil {
            let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
            
            prefsWindowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Preferences")) as? PrefsWindowController
        }
        
        guard let prefsWindowController = prefsWindowController else { return }
        
        prefsWindowController.showWindow(nil)
        prefsWindowController.window?.makeKeyAndOrderFront(prefsWindowController)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func new(_ sender: Any?) {
        mainWindowController?.makeNew()
        NSApp.activate(ignoringOtherApps: true)
        ViewController.shared()?.fileMenuNewNote(self)
    }
    
    @IBAction func newRTF(_ sender: Any?) {
        mainWindowController?.makeNew()
        NSApp.activate(ignoringOtherApps: true)
        ViewController.shared()?.fileMenuNewRTF(self)
    }
    
    @IBAction func searchAndCreate(_ sender: Any?) {
        mainWindowController?.makeNew()
        NSApp.activate(ignoringOtherApps: true)
        
        guard let vc = ViewController.shared() else { return }
        
        DispatchQueue.main.async {
            vc.search.window?.makeFirstResponder(vc.search)
        }
    }
    
    @IBAction func removeMenuBar(_ sender: Any?) {
        guard let statusItem = statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
    }
    
    @IBAction func addMenuBar(_ sender: Any?) {
        constructMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == NSEvent.EventType.leftMouseDown {
            mainWindowController?.makeNew()
        }
    }
}
