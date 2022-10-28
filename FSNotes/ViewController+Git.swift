//
//  ViewController+Git.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 9/10/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Git
import Cgit2

extension EditorViewController {

    @IBAction func saveRevision(_ sender: NSMenuItem) {
        guard let window = self.view.window else { return }
        if UserDefaultsManagement.askCommitMessage {
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 60))
            if let lastMessage = UserDefaultsManagement.lastCommitMessage {
                field.stringValue = lastMessage
            }
            
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Commit message:", comment: "")
            alert.accessoryView = field
            alert.alertStyle = .informational
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    let commitMessage: String? = field.stringValue.count > 0 ? field.stringValue : nil
                    
                    if field.stringValue.count > 0 {
                        UserDefaultsManagement.lastCommitMessage = commitMessage
                    }
                    
                    self.saveRevision(commitMessage: commitMessage)
                }
            }
            
            field.becomeFirstResponder()
            return
        }
        
        saveRevision(commitMessage: nil)
    }
    
    private func saveRevision(commitMessage: String? = nil) {
        guard let note = getSelectedNotes()?.first, let window = self.view.window else { return }
        
        ViewController.shared()?.gitQueue.addOperation({
            let project = note.project.getGitProject()
            try? project.commit(message: commitMessage)

            // No hands – no mults
            guard project.getGitOrigin() != nil else { return }
            
            do {
                try project.pull()
                print("Pull successful")
                
                try project.push()
                print("Push successful")
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .critical
                    alert.informativeText = NSLocalizedString("Git error", comment: "")
                    alert.messageText = error.localizedDescription
                    alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in }
                }
            }
        })
    }

    @IBAction func checkoutRevision(_ sender: NSMenuItem) {
        guard let commit = sender.representedObject as? FSCommit else { return }
        guard let note = vcEditor?.note else { return }
        let git = FSGit.sharedInstance()

        UserDataService.instance.fsUpdatesDisabled = true

        let repository = git.getRepository(by: note.project.getGitProject())

        if git.prevCommit == nil {
            saveRevision(commitMessage: nil)
        }

        print(note.getGitPath())
        repository.checkout(commit: commit, fileName: note.getGitPath())
        git.prevCommit = commit

        _ = note.reload()
        NotesTextProcessor.highlight(note: note)
        reloadAllOpenedWindows(note: note)
        
        ViewController.shared()?.notesTableView.reloadRow(note: note)

        vcEditor?.scanTagsAndAutoRename()

        UserDataService.instance.fsUpdatesDisabled = false
    }

    @IBAction private func makeFullSnapshot(_ sender: Any) {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let minute = cal.component(.minute, from: Date())

        if minute == lastSnapshot {
            return
        }

        lastSnapshot = minute

        guard UserDefaultsManagement.snapshotsInterval != 0 && (
            hour == UserDefaultsManagement.snapshotsInterval || (
                hour != 0 && hour % UserDefaultsManagement.snapshotsInterval == 0
            )
        ) else { return }

        guard UserDefaultsManagement.snapshotsIntervalMinutes == minute else { return }

        let storage = Storage.sharedInstance()
        let projects = storage.getProjects()

        ViewController.shared()?.gitQueue.addOperation({
            for project in projects {
                if project.isTrash {
                    continue
                }

                if project.isRoot || project.isArchive || project.isGitOriginExist()  {
                    try? project.commit()
                    
                    if project.isGitOriginExist() {
                        try? project.pull()
                        try? project.push()
                    }
                }
            }
        })
    }
    
    @IBAction private func pull(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        
        let storage = Storage.sharedInstance()
        let projects = storage.getProjects()

        // Skip on high load
        if vc.gitQueue.operationCount > 5 {
            return
        }
        
        vc.gitQueue.addOperation({
            for project in projects {
                if project.isTrash {
                    continue
                }

                if project.isRoot || project.isArchive || project.isGitOriginExist()  {
                    try? project.pull()
                }
            }
        })
    }

    public func scheduleSnapshots() {
        guard !UserDefaultsManagement.backupManually else { return }

        snapshotsTimer.invalidate()
        snapshotsTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(makeFullSnapshot), userInfo: nil, repeats: true)
    }
    
    public func schedulePull() {
        guard !UserDefaultsManagement.backupManually else { return }

        let interval = UserDefaultsManagement.pullInterval
        
        pullTimer.invalidate()
        pullTimer = Timer.scheduledTimer(timeInterval: TimeInterval(interval), target: self, selector: #selector(pull), userInfo: nil, repeats: true)
    }
    
    public func stopPull() {
        pullTimer.invalidate()
    }
}
