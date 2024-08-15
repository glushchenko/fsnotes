//
//  SettingsViewController.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 14.03.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import AppKit

class SettingsViewController: NSViewController, NSTextFieldDelegate {

    public var gitProject: Project?
    public var project: Project?
    public var progress: GitProgress?

    override func viewDidAppear() {
        passphrase.delegate = self
        origin.delegate = self
    }

    @IBOutlet weak var origin: NSTextField!
    @IBOutlet weak var keyStatus: NSTextField!
    @IBOutlet weak var logTextField: NSTextField!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var cloneButton: NSButton!
    @IBOutlet weak var passphrase: NSSecureTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    @IBAction func removeRepository(_ sender: Any) {
        gitProject?.removeRepository(progress: progress)

        updateButtons()
    }

    @IBAction func origin(_ sender: Any) {
        gitProject?.settings.setOrigin(origin.stringValue)
        gitProject?.saveSettings()

        updateButtons()
    }

    @IBAction func passphrase(_ sender: Any) {
        gitProject?.settings.gitPrivateKeyPassphrase = passphrase.stringValue
        gitProject?.saveSettings()
    }

    @IBAction func clonePull(_ sender: Any) {
        guard let project = self.gitProject else { return }

        if let origin = project.settings.gitOrigin, origin.startsWith(string: "https://") {
            let alert = NSAlert()
            alert.messageText = "Wrong configuration"
            alert.alertStyle = .critical
            alert.informativeText = "Please use ssh keys, https auth is not supported"
            alert.runModal()
            return
        }

        let action = project.getRepositoryState()
        updateButtons(isActive: true)

        ViewController.gitQueue.addOperation({
            defer {
                ViewController.gitQueueOperationDate = nil
                ViewController.gitQueueBusy = false
                
                DispatchQueue.main.async {
                    self.updateButtons(isActive: false)
                }
            }

            ViewController.gitQueueOperationDate = Date()
            ViewController.gitQueueBusy = true

            if let message = project.gitDo(action, progress: self.progress) {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .critical
                    alert.informativeText = message
                    alert.messageText = NSLocalizedString("git error", comment: "")
                    alert.runModal()
                }
            }
        })
    }

    @IBAction func privateKey(_ sender: Any) {
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

                self.gitProject?.settings.gitPrivateKey = try? Data(contentsOf: openPanel.urls[0])
                self.gitProject?.saveSettings()

                self.keyStatus.stringValue = "✅"
            }
        }
    }

    @IBAction func resetKey(_ sender: Any) {
        gitProject?.removeSSHKey()
        gitProject?.settings.gitPrivateKey = nil
        gitProject?.saveSettings()

        keyStatus.stringValue = ""
    }

    public func controlTextDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else { return }

        if textField.identifier?.rawValue == "gitOrigin" {
            gitProject?.settings.setOrigin(textField.stringValue)
            updateButtons()
        }

        if textField.identifier?.rawValue == "gitPassphrase" {
            gitProject?.settings.gitPrivateKeyPassphrase = textField.stringValue
        }

        DispatchQueue.global(qos: .background).async {
            self.gitProject?.saveSettings()
        }
    }

    public func updateButtons(isActive: Bool? = nil) {
        guard let project = gitProject else { return }

        progressIndicator.isHidden = !project.isActiveGit
        cloneButton.title = project.getRepositoryState().title
        removeButton.isEnabled = project.hasRepository()

        if let isActive = isActive {
            if isActive {
                progressIndicator.startAnimation(nil)
                progressIndicator.isHidden = false
            } else {
                progressIndicator.stopAnimation(nil)
                progressIndicator.isHidden = true
            }
        }
    }

    public func loadGit(project: Project) {
        var project = project

        if project.isVirtual  {
            if let defaultProject = Storage.shared().getDefault() {
                project = defaultProject
            }
        }

        self.gitProject = project

        origin.stringValue = project.settings.gitOrigin ?? ""
        passphrase.stringValue = project.settings.gitPrivateKeyPassphrase ?? ""
        keyStatus.stringValue = project.settings.gitPrivateKey != nil ? "✅" : ""

        updateButtons()
        progress = GitProgress(statusTextField: logTextField, project: project)

        // Global instance for libgit2 callbacks
        AppDelegate.gitProgress = progress

        if let status = project.gitStatus {
            logTextField.stringValue = status
        }
    }
}
