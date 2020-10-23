//
//  PreferencesGeneralViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import MASShortcut
import CoreData
import FSNotesCore_macOS

class PreferencesGeneralViewController: NSViewController {
    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 476, height: 481)
    }

    @IBOutlet var externalEditorApp: NSTextField!
    @IBOutlet var newNoteshortcutView: MASShortcutView!
    @IBOutlet var searchNotesShortcut: MASShortcutView!
    @IBOutlet weak var defaultStoragePath: NSPathControl!
    @IBOutlet weak var showDockIcon: NSButton!
    @IBOutlet weak var searchFocusOnESC: NSButton!
    @IBOutlet weak var showInMenuBar: NSButton!
    @IBOutlet weak var defaultExtension: NSPopUpButton!
    @IBOutlet weak var fileContainer: NSPopUpButton!
    @IBOutlet weak var filesNaming: NSPopUpButton!

    //MARK: global variables

    let storage = Storage.sharedInstance()

    override func viewDidLoad() {
        super.viewDidLoad()
        initShortcuts()
    }

    override func viewDidAppear() {
        self.view.window!.title = NSLocalizedString("Preferences", comment: "")

        externalEditorApp.stringValue = UserDefaultsManagement.externalEditor

        if let url = UserDefaultsManagement.storageUrl {
            defaultStoragePath.stringValue = url.path
        }

        showDockIcon.state = UserDefaultsManagement.showDockIcon ? .on : .off

        searchFocusOnESC.state = UserDefaultsManagement.shouldFocusSearchOnESCKeyDown ? .on : .off
        
        showInMenuBar.state = UserDefaultsManagement.showInMenuBar ? .on : .off

        fileContainer.selectItem(withTag: UserDefaultsManagement.fileContainer.tag)

        filesNaming.selectItem(withTag: UserDefaultsManagement.naming.tag)

        let ext = UserDefaultsManagement.noteExtension
        defaultExtension.selectItem(withTitle: "." + ext)
    }

    @IBAction func changeDefaultStorage(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                guard let url = openPanel.url else { return }
                guard let currentURL = UserDefaultsManagement.storageUrl else { return }

                let bookmark = SandboxBookmark.sharedInstance()
                let activeBookmars = bookmark.load()
                bookmark.remove(url: currentURL)
                bookmark.store(url: url)
                bookmark.save()

                UserDefaultsManagement.storageType = .custom
                UserDefaultsManagement.storagePath = url.path

                self.defaultStoragePath.stringValue = url.path

                // Resets archive if not bookmarked
                if let archiveURL = UserDefaultsManagement.archiveDirectory, !activeBookmars.contains(archiveURL) {
                    UserDefaultsManagement.archiveDirectory = nil
                }

                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    let message = NSLocalizedString("Do you want to move current notes in the new destination?", comment: "");
                    appDelegate.promptToMoveDatabase(from: currentURL, to: url, messageText: message)
                }

                self.restart()
            }
        }
    }

    @IBAction func externalEditor(_ sender: Any) {
        UserDefaultsManagement.externalEditor = externalEditorApp.stringValue
    }

    @IBAction func showDockIcon(_ sender: NSButton) {
        let isEnabled = sender.state == .on
        UserDefaultsManagement.showDockIcon = isEnabled

        NSApp.setActivationPolicy(isEnabled ? .regular : .accessory)

        DispatchQueue.main.async {
            NSMenu.setMenuBarVisible(true)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @IBAction func searchFocusOnESC(_ sender: NSButton) {
        UserDefaultsManagement.shouldFocusSearchOnESCKeyDown = sender.state == .on
    }
     
    @IBAction func showInMenuBar(_ sender: NSButton) {
        UserDefaultsManagement.showInMenuBar = sender.state == .on

        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }

        if sender.state == .off {
            appDelegate.removeMenuBar(nil)
            return
        }

        appDelegate.addMenuBar(nil)
    }

    @IBAction func fileContainer(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }

        if let container = NoteContainer(rawValue: item.tag) {
            UserDefaultsManagement.fileContainer = container
        }
    }

    @IBAction func defaultExtension(_ sender: NSPopUpButton) {
        let ext = sender.title.replacingOccurrences(of: ".", with: "")

        UserDefaultsManagement.noteExtension = ext

        if ext == "rtf" {
            UserDefaultsManagement.fileFormat = .RichText
        } else {
            UserDefaultsManagement.fileFormat = .Markdown
        }
    }

    @IBAction func filesNaming(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }

        if let naming = SettingsFilesNaming(rawValue: item.tag) {
            UserDefaultsManagement.naming = naming
        }
    }

    func restart() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        exit(0)
    }

    func initShortcuts() {
        guard let vc = ViewController.shared() else { return }

        let mas = MASShortcutMonitor.shared()
        
        newNoteshortcutView.shortcutValue = UserDefaultsManagement.newNoteShortcut
        searchNotesShortcut.shortcutValue = UserDefaultsManagement.searchNoteShortcut

        newNoteshortcutView.shortcutValidator.allowAnyShortcutWithOptionModifier = true
        searchNotesShortcut.shortcutValidator.allowAnyShortcutWithOptionModifier = true

        newNoteshortcutView.shortcutValueChange = { (sender) in
            if ((self.newNoteshortcutView.shortcutValue) != nil) {
                mas?.unregisterShortcut(UserDefaultsManagement.newNoteShortcut)

                let keyCode = self.newNoteshortcutView.shortcutValue.keyCode
                let modifierFlags = self.newNoteshortcutView.shortcutValue.modifierFlags

                UserDefaultsManagement.newNoteShortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)

                MASShortcutMonitor.shared().register(self.newNoteshortcutView.shortcutValue, withAction: {
                    vc.makeNoteShortcut()
                })
            } else {
                mas?.unregisterShortcut(UserDefaultsManagement.newNoteShortcut)

                UserDefaultsManagement.newNoteShortcut = nil
            }
        }

        searchNotesShortcut.shortcutValueChange = { (sender) in
            if ((self.searchNotesShortcut.shortcutValue) != nil) {
                mas?.unregisterShortcut(UserDefaultsManagement.searchNoteShortcut)

                let keyCode = self.searchNotesShortcut.shortcutValue.keyCode
                let modifierFlags = self.searchNotesShortcut.shortcutValue.modifierFlags

                UserDefaultsManagement.searchNoteShortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)

                MASShortcutMonitor.shared().register(self.searchNotesShortcut.shortcutValue, withAction: {
                    vc.searchShortcut()
                })
            } else {
                mas?.unregisterShortcut(UserDefaultsManagement.searchNoteShortcut)

                UserDefaultsManagement.searchNoteShortcut = nil
            }
        }
    }
}
