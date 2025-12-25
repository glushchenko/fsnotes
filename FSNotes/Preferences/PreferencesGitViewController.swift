//
//  PreferencesGitViewController.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 9/8/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PreferencesGitViewController: SettingsViewController {

    @IBOutlet weak var repositoriesPath: NSPathControl!
    @IBOutlet weak var snapshotsTextField: NSTextField!
    @IBOutlet weak var minutes: NSTextField!
    @IBOutlet weak var backupManually: NSButton!
    @IBOutlet weak var backupBySchedule: NSButton!
    @IBOutlet weak var pullInterval: NSTextField!
    @IBOutlet weak var separateDotGit: NSButton!
    @IBOutlet weak var askCommitMessage: NSButton!

    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 550, height: 579)

        loadGit(project: Storage.shared().getDefault()!)

        repositoriesPath.url = UserDefaultsManagement.gitStorage
        snapshotsTextField.stringValue = String(UserDefaultsManagement.snapshotsInterval)
        minutes.stringValue = String(UserDefaultsManagement.snapshotsIntervalMinutes)
        backupManually.state = UserDefaultsManagement.backupManually ? .on : .off
        backupBySchedule.state = UserDefaultsManagement.backupManually ? .off : .on
        pullInterval.stringValue = String(UserDefaultsManagement.pullInterval)
        separateDotGit.state = UserDefaultsManagement.separateRepo ? .on : .off
        askCommitMessage.state = UserDefaultsManagement.askCommitMessage ? .on : .off
    }

    @IBAction func changeGitStorage(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = UserDefaultsManagement.gitStorage
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.begin { (result) -> Void in
            if result == .OK {
                guard let url = openPanel.url?.standardized,
                    url != UserDefaultsManagement.storageUrl else {
                        let alert = NSAlert()
                        alert.alertStyle = .critical
                        alert.informativeText = NSLocalizedString("Path not available", comment: "")
                        alert.messageText = NSLocalizedString("Default storage path should not be equal to Git path.", comment: "")
                        alert.runModal()
                        return
                }

                let bookmarksManager = SandboxBookmark.sharedInstance()
                
                if let currentURL = UserDefaultsManagement.gitStorage {
                    bookmarksManager.remove(url: currentURL)
                }
                
                bookmarksManager.store(url: url)
                bookmarksManager.save()

                UserDefaultsManagement.gitStorage = url
                self.repositoriesPath.url = url
            }
        }
    }

    @IBAction func showFinder(_ sender: Any) {
        guard let storage = UserDefaultsManagement.gitStorage else { return }
        
        NSWorkspace.shared.activateFileViewerSelecting([storage])
    }

    @IBAction func showTerminal(_ sender: Any) {
        guard let storage = UserDefaultsManagement.gitStorage else { return }
        
        NSWorkspace.shared.openFile(storage.path, withApplication: "Terminal.app")
    }

    @IBAction func backupMethod(_ sender: NSButton) {
        guard let ident = sender.identifier?.rawValue else { return }
        
        let isManualBackup = ident == "manual"
        
        UserDefaultsManagement.backupManually = isManualBackup
        backupManually.state = isManualBackup ? .on : .off
        backupBySchedule.state = isManualBackup ? .off : .on
        
        guard let vc = ViewController.shared() else { return }
        if backupBySchedule.state == .on {
            vc.schedulePull()
        } else {
            vc.stopPull()
        }
    }

    @IBAction func changeSnapshotIntervalByHours(_ sender: NSTextField) {
        if sender.stringValue == "0" || sender.stringValue.trim() == "" {
            sender.stringValue = "1"
        }
        
        if let interval = Int(sender.stringValue) {
            UserDefaultsManagement.snapshotsInterval = interval
        }

        guard let vc = ViewController.shared() else { return }
        vc.scheduleSnapshots()
    }

    @IBAction func changeSnapshotsIntervalByMinutes(_ sender: NSTextField) {
        if let interval = Int(sender.stringValue) {
            UserDefaultsManagement.snapshotsIntervalMinutes = interval
        }

        guard let vc = ViewController.shared() else { return }
        vc.scheduleSnapshots()
    }

    @IBAction func pullInterval(_ sender: NSTextField) {
        if var interval = Int(sender.stringValue) {
            if interval < 10 {
                interval = 10
                pullInterval.stringValue = String(10)
            }
            
            UserDefaultsManagement.pullInterval = interval
        }

        guard let vc = ViewController.shared() else { return }
        vc.schedulePull()
    }
    
    @IBAction func separateRepo(_ sender: NSButton) {
        UserDefaultsManagement.separateRepo = sender.state == .on
    }
    
    @IBAction func askCommitMessage(_ sender: NSButton) {
        UserDefaultsManagement.askCommitMessage = sender.state == .on
    }
}
