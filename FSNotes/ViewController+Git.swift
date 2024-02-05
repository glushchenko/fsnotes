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
        guard let note = getSelectedNotes()?.first else { return }
        if !note.hasGitRepository() {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.informativeText = NSLocalizedString("Please init git repository before (Preferences -> Git -> Init/commit)", comment: "")
            alert.messageText = NSLocalizedString("Repository not found", comment: "")
            alert.runModal()
            return
        }

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

        ViewController.gitQueue.addOperation({
            ViewController.gitQueueOperationDate = Date()

            defer {
                ViewController.gitQueueOperationDate = nil
            }

            do {
                try note.getGitProject()?.saveRevision(commitMessage: commitMessage)
            } catch GitError.noAddedFiles {
                // pass
            } catch {
                var message = String()
                if let error = error as? GitError {
                    message = error.associatedValue()
                } else {
                    message = error.localizedDescription
                }

                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .critical
                    alert.informativeText = message
                    alert.messageText = NSLocalizedString("Git error", comment: "")
                    alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in }
                }
            }
        })
    }

    @IBAction func checkoutRevision(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }
        guard let commit = sender.representedObject as? Commit else { return }
        guard let note = vcEditor?.note else { return }

        if vc.prevCommit == nil {
            saveRevision(commitMessage: "Auto save on history checkout")
        }

        vc.prevCommit = commit
        
        note.checkout(commit: commit)

        _ = note.reload()
        NotesTextProcessor.highlight(note: note)
        reloadAllOpenedWindows(note: note)
        
        ViewController.shared()?.notesTableView.reloadRow(note: note)

        vcEditor?.scanTagsAndAutoRename()
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

        ViewController.gitQueue.addOperation({
            ViewController.gitQueueOperationDate = Date()

            defer {
                ViewController.gitQueueOperationDate = nil
            }

            let storage = Storage.shared()
            guard let projects = storage.getGitProjects() else { return }

            for project in projects {
                do {
                    if project.hasRepository()  {
                        try project.commit()
                        try project.pull()
                        try project.push()
                    }
                } catch {
                    print(error)
                }
            }
        })
    }
    
    @IBAction private func pull(_ sender: Any) {

        // Restart queue if operation stucked more then 2 minutes
        if let date = ViewController.gitQueueOperationDate {
            let diff = Int(Date().timeIntervalSince1970) - Int(date.timeIntervalSince1970)
            let isBusy = ViewController.gitQueueBusy

            if diff > 120 && !isBusy {

                ViewController.gitQueue = OperationQueue()
                ViewController.gitQueue.maxConcurrentOperationCount = 1

                print("Git queue restart")
            } else {
                print("Git pull skipped")
                return
            }
        }

        ViewController.gitQueue.addOperation({
            ViewController.gitQueueOperationDate = Date()

            defer {
                ViewController.gitQueueOperationDate = nil
            }

            Storage.shared().pullAll()
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
