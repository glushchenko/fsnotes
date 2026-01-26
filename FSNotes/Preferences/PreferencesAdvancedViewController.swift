//
//  PreferencesAdvancedViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PreferencesAdvancedViewController: NSViewController {
    override func viewWillAppear() {
        super.viewWillAppear()
    }

    @IBOutlet weak var languagePopUp: NSPopUpButton!
    @IBOutlet weak var version: NSTextField!
    @IBOutlet weak var appearance: NSPopUpButton!
    @IBOutlet weak var appearanceLabel: NSTextField!

    @IBOutlet weak var dockIconFirst: NSButton!
    @IBOutlet weak var dockIconSecond: NSButton!

    @IBOutlet weak var trashPath: NSPathControl!
    
    @IBAction func appearanceClick(_ sender: NSPopUpButton) {
        if let type = AppearanceType(rawValue: sender.indexOfSelectedItem) {
            UserDefaultsManagement.appearanceType = type
        }

        restart()
    }

    override func viewDidAppear() {
        let languages = [
            LanguageType(rawValue: 0),
            LanguageType(rawValue: 1),
            LanguageType(rawValue: 2),
            LanguageType(rawValue: 5),
            LanguageType(rawValue: 6),
            LanguageType(rawValue: 18),
            LanguageType(rawValue: 15),
            LanguageType(rawValue: 3),
            LanguageType(rawValue: 9),
            LanguageType(rawValue: 8),
            LanguageType(rawValue: 12),
            LanguageType(rawValue: 16),
            LanguageType(rawValue: 11),
            LanguageType(rawValue: 13),
            LanguageType(rawValue: 7),
            LanguageType(rawValue: 10),
            LanguageType(rawValue: 14),
            LanguageType(rawValue: 4),
            LanguageType(rawValue: 17)
        ]

        for language in languages {
            if let lang = language?.description, let id = language?.rawValue {
                languagePopUp.addItem(withTitle: lang)
                languagePopUp.lastItem?.state = (id == UserDefaultsManagement.defaultLanguage) ? .on : .off

                if id == UserDefaultsManagement.defaultLanguage {
                    languagePopUp.selectItem(withTitle: lang)
                }
            }
        }

        if #available(OSX 10.14, *) {
            appearance.selectItem(at: UserDefaultsManagement.appearanceType.rawValue)
        } else {
            appearanceLabel.isHidden = true
            appearance.isHidden = true
        }

        if let dictionary = Bundle.main.infoDictionary,
            let ver = dictionary["CFBundleShortVersionString"] as? String,
            let build = dictionary["CFBundleVersion"] as? String {
            version.stringValue = "v\(ver) build \(build)"
        }

        switch UserDefaultsManagement.dockIcon {
        case 0:
            dockIconFirst.state = .on
            break
        case 1:
            dockIconSecond.state = .on
            break
        default:
            dockIconFirst.state = .on
        }
        
        if let url = Storage.shared().getDefaultTrash()?.url {
            trashPath.url = url
        }
    }

    @IBAction func languagePopUp(_ sender: NSPopUpButton) {
        let type = LanguageType.withName(rawValue: sender.title)

        UserDefaultsManagement.defaultLanguage = type.rawValue

        UserDefaults.standard.set([type.code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        restart()
    }

    private func restart() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        exit(0)
    }

    @IBAction func dockIcon(_ sender: NSButton) {
        UserDefaultsManagement.dockIcon = sender.tag

        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.loadDockIcon()
    }

    @IBAction func trash(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = Storage.shared().getDefaultTrash()?.url
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canSelectHiddenExtension = true
        openPanel.begin { (result) -> Void in
            if result == .OK {
                guard let url = openPanel.url else { return }

                let bookmarksManager = SandboxBookmark.sharedInstance()

                if let currentURL = UserDefaultsManagement.trashURL {
                    bookmarksManager.remove(url: currentURL)
                }

                bookmarksManager.store(url: url)
                bookmarksManager.save()

                UserDefaultsManagement.trashURL = url
                self.trashPath.url = url
                
                Storage.shared().getDefaultTrash()?.url = url
                self.restart()
            }
        }
    }
    
    @IBAction func resetCaches(_ sender: Any) {
        if let sidebarTreeURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("sidebarTree") {
            try? FileManager.default.removeItem(at: sidebarTreeURL)
        }
        
        let projects = Storage.shared().getProjects()
        for project in projects {
            if let cacheUrl = project.getCacheURL() {
                try? FileManager.default.removeItem(at: cacheUrl)
            }

            project.isReadyForCacheSaving = false
        }

        restart()
    }
    
    @IBAction func resetSettings(_ sender: Any) {
        let store = NSUbiquitousKeyValueStore.default
        for (key, _) in store.dictionaryRepresentation {
            store.removeObject(forKey: key)
        }
        store.synchronize()
        
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        
        if let userDefaultsURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Preferences").appendingPathComponent("co.fluder.FSNotes.plist") {
            try? FileManager.default.removeItem(at: userDefaultsURL)
        }
        
        if let editorsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("editors.settings") {
            try? FileManager.default.removeItem(at: editorsURL)
        }
        
        if let notesURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("notes.settings") {
            try? FileManager.default.removeItem(at: notesURL)
        }
        
        if let bookmarkUrls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Bookmarks.dict") {
            try? FileManager.default.removeItem(at: bookmarkUrls)
        }
        
        restart()
    }
}
