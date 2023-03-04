//
//  PreferencesGitViewController.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 9/8/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PreferencesGitViewController: NSViewController {

    @IBOutlet weak var repositoriesPath: NSPathControl!
    @IBOutlet weak var snapshotsTextField: NSTextField!
    @IBOutlet weak var minutes: NSTextField!
    @IBOutlet weak var gitVersion: NSTextField!
    @IBOutlet weak var backupManually: NSButton!
    @IBOutlet weak var backupBySchedule: NSButton!
    @IBOutlet weak var origin: NSTextField!
    @IBOutlet weak var username: NSTextField!
    @IBOutlet weak var password: NSSecureTextField!
    @IBOutlet weak var rsaPath: NSPathControl!
    @IBOutlet weak var passphrase: NSSecureTextField!
    @IBOutlet weak var pullInterval: NSTextField!
    @IBOutlet weak var customWorktree: NSButton!
    @IBOutlet weak var separateDotGit: NSButton!
    @IBOutlet weak var askCommitMessage: NSButton!
    
    override func viewWillAppear() {
        super.viewWillAppear()
        //preferredContentSize = NSSize(width: 550, height: 612)

        repositoriesPath.url = UserDefaultsManagement.gitStorage

        snapshotsTextField.stringValue = String(UserDefaultsManagement.snapshotsInterval)

        minutes.stringValue = String(UserDefaultsManagement.snapshotsIntervalMinutes)

        backupManually.state = UserDefaultsManagement.backupManually ? .on : .off
        backupBySchedule.state = UserDefaultsManagement.backupManually ? .off : .on
        
        origin.stringValue = UserDefaultsManagement.gitOrigin ?? ""
        username.stringValue = UserDefaultsManagement.gitUsername ?? ""
        password.stringValue = UserDefaultsManagement.gitPassword ?? ""
        
        if let accessData = UserDefaultsManagement.gitPrivateKeyData,
            let bookmarks = NSKeyedUnarchiver.unarchiveObject(with: accessData) as? [URL: Data] {
            
            for bookmark in bookmarks {
                rsaPath.url = bookmark.key
                break
            }
        }
        
        passphrase.stringValue = UserDefaultsManagement.gitPassphrase
        pullInterval.stringValue = String(UserDefaultsManagement.pullInterval)
        
        customWorktree.state = UserDefaultsManagement.separateRepo ? .off : .on
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

                let currentURL = UserDefaultsManagement.gitStorage

                let bookmark = SandboxBookmark.sharedInstance()
                _ = bookmark.load()
                bookmark.remove(url: currentURL)
                bookmark.store(url: url)
                bookmark.save()

                UserDefaultsManagement.gitStorage = url
                self.repositoriesPath.url = url
            }
        }
    }

    @IBAction func showFinder(_ sender: Any) {
        NSWorkspace.shared.activateFileViewerSelecting([UserDefaultsManagement.gitStorage])
    }

    @IBAction func showTerminal(_ sender: Any) {
        NSWorkspace.shared.openFile(UserDefaultsManagement.gitStorage.path, withApplication: "Terminal.app")
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
    
    @IBAction func origin(_ sender: NSTextField) {
        let project = Storage.shared().getDefault()
        project?.settings.gitOrigin = sender.stringValue
        project?.saveSettings()
        
        ViewController.shared()?.gitQueue.cancelAllOperations()
    }
    
    @IBAction func username(_ sender: NSTextField) {
        UserDefaultsManagement.gitUsername = sender.stringValue
    }
    
    @IBAction func password(_ sender: NSSecureTextField) {
        UserDefaultsManagement.gitPassword = sender.stringValue
    }
    
    @IBAction func rsaKey(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseFiles = true
        openPanel.begin { (result) -> Void in
            if result == .OK {
                if openPanel.urls.count != 1 {
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.informativeText = NSLocalizedString("Please select private key", comment: "")
                    alert.runModal()
                    return
                }
                
                var bookmarks = [URL: Data]()
                for url in openPanel.urls {
                    do {
                        let data = try url.bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        
                        bookmarks[url] = data
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                
                let data = NSKeyedArchiver.archivedData(withRootObject: bookmarks)
                UserDefaultsManagement.gitPrivateKeyData = data
                
                self.rsaPath.url = openPanel.urls[0]
            }
        }
    }
    
    @IBAction func passphrase(_ sender: NSSecureTextField) {
        UserDefaultsManagement.gitPassphrase = sender.stringValue
    }
    
    @IBAction func pullInterval(_ sender: NSTextField) {
        ViewController.shared()?.gitQueue.cancelAllOperations()
        
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
        UserDefaultsManagement.separateRepo = (sender.tag == 1)
    }
    
    @IBAction func askCommitMessage(_ sender: NSButton) {
        UserDefaultsManagement.askCommitMessage = sender.state == .on
    }
    
    @IBAction func clonePull(_ sender: Any) {
        guard let project = Storage.shared().getDefault() else { return }
        guard let window = view.window else { return }
        
        ViewController.shared()?.gitQueue.cancelAllOperations()
        
        let origin = self.origin.stringValue
        project.settings.gitOrigin = origin
        project.saveSettings()
        
        ProjectSettingsViewController.cloneAndPull(origin: origin, project: project, window: window)
    }
    
    @IBAction func resetGitKeys(_ sender: NSButton) {
        UserDefaultsManagement.gitPrivateKeyData = nil
        rsaPath.url = nil
    }
}
