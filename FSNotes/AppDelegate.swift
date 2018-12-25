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

    func applicationWillFinishLaunching(_ notification: Notification) {
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

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }

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
}
