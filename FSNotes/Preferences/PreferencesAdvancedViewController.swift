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

    @IBOutlet weak var archivePathControl: NSPathControl!
    @IBOutlet weak var languagePopUp: NSPopUpButton!
    @IBOutlet weak var version: NSTextField!
    @IBOutlet weak var appearance: NSPopUpButton!
    @IBOutlet weak var appearanceLabel: NSTextField!

    @IBOutlet weak var dockIconFirst: NSButton!
    @IBOutlet weak var dockIconSecond: NSButton!

    @IBOutlet weak var markdownPreviewCSS: NSPathControl!
    @IBOutlet weak var trashPath: NSPathControl!
    
    @IBAction func appearanceClick(_ sender: NSPopUpButton) {
        if let type = AppearanceType(rawValue: sender.indexOfSelectedItem) {
            UserDefaultsManagement.appearanceType = type
        }

        restart()
    }

    override func viewDidAppear() {
        if let archiveDirectory = UserDefaultsManagement.archiveDirectory {
            archivePathControl.url = archiveDirectory
        }

        let languages = [
            LanguageType(rawValue: 0x00),
            LanguageType(rawValue: 0x01),
            LanguageType(rawValue: 0x02),
            LanguageType(rawValue: 0x03),
            LanguageType(rawValue: 0x04),
            LanguageType(rawValue: 0x05),
            LanguageType(rawValue: 0x06),
            LanguageType(rawValue: 0x07),
            LanguageType(rawValue: 0x08),
            LanguageType(rawValue: 0x09),
            LanguageType(rawValue: 10),
            LanguageType(rawValue: 11),
            LanguageType(rawValue: 12),
            LanguageType(rawValue: 13)
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

        if let preview = UserDefaultsManagement.markdownPreviewCSS {
            markdownPreviewCSS.url = preview
        }
        
        if let url = Storage.shared().getDefaultTrash()?.url {
            trashPath.url = url
        }
    }

    @IBAction func changeArchiveStorage(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = UserDefaultsManagement.archiveDirectory
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.begin { (result) -> Void in
            if result == .OK {
                guard let url = openPanel.url else { return }
                guard let currentURL = UserDefaultsManagement.archiveDirectory else { return }

                let bookmark = SandboxBookmark.sharedInstance()
                _ = bookmark.load()
                bookmark.remove(url: currentURL)
                bookmark.store(url: url)
                bookmark.save()

                UserDefaultsManagement.archiveDirectory = url
                self.archivePathControl.url = url

                let storage = Storage.shared()
                guard let vc = ViewController.shared() else { return }

                if let archive = storage.getArchive() {
                    archive.url = url
                    storage.unload(project: archive)
                    storage.loadNotes(archive)

                    vc.fsManager?.restart()
                    vc.notesTableView.reloadData()
                    vc.sidebarOutlineView.reloadData()
                    vc.sidebarOutlineView.selectSidebar(type: .Archive)
                }
            }
        }
    }

//    @IBAction func changeMarkdownStyle(_ sender: Any) {
//        let openPanel = NSOpenPanel()
//        openPanel.allowsMultipleSelection = false
//        openPanel.canChooseDirectories = false
//        openPanel.canCreateDirectories = true
//        openPanel.canChooseFiles = true
//        openPanel.allowedFileTypes = ["css"]
//        openPanel.begin { (result) -> Void in
//            if result == .OK {
//                guard let url = openPanel.url else { return }
//
//                let bookmark = SandboxBookmark.sharedInstance()
//                _ = bookmark.load()
//
//                if let currentURL = UserDefaultsManagement.markdownPreviewCSS {
//                    bookmark.remove(url: currentURL)
//                }
//
//                bookmark.store(url: url)
//                bookmark.save()
//
//                UserDefaultsManagement.markdownPreviewCSS = url
//                self.markdownPreviewCSS.url = url
//
//                let webkitPreview = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wkPreview")
//
//                try? FileManager.default.removeItem(at: webkitPreview)
//
//                let editors = AppDelegate.getEditTextViews()
//                for editor in editors {
//                    editor.editorViewController?.refillEditArea()
//                }
//            }
//        }
//    }

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
    
    @IBAction func editCss(_ sender: Any) {
        if let url = UserDefaultsManagement.markdownPreviewCSS {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
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

                let bookmark = SandboxBookmark.sharedInstance()
                _ = bookmark.load()

                if let currentURL = UserDefaultsManagement.trashURL {
                    bookmark.remove(url: currentURL)
                }

                bookmark.store(url: url)
                bookmark.save()

                UserDefaultsManagement.trashURL = url
                self.trashPath.url = url
                
                Storage.shared().getDefaultTrash()?.url = url
                self.restart()
            }
        }
    }
    
}
