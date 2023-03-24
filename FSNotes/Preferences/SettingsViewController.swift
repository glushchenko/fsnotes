//
//  SettingsViewController.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 14.03.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import AppKit

class SettingsViewController: NSViewController, NSTextFieldDelegate {

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
        project?.removeRepository(progress: progress)

        updateButtons()
    }

    @IBAction func origin(_ sender: Any) {
        project?.settings.setOrigin(origin.stringValue)
        project?.saveSettings()

        updateButtons()
    }

    @IBAction func passphrase(_ sender: Any) {
        project?.settings.gitPrivateKeyPassphrase = passphrase.stringValue
        project?.saveSettings()
    }

    @IBAction func clonePull(_ sender: Any) {
        guard let project = self.project else { return }

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

        ViewController.shared()?.gitQueue.cancelAllOperations()
        ViewController.shared()?.gitQueue.addOperation({
            defer {
                DispatchQueue.main.async {
                    self.updateButtons(isActive: false)
                }
            }

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

                self.project?.settings.gitPrivateKey = try? Data(contentsOf: openPanel.urls[0])
                self.project?.saveSettings()

                self.keyStatus.stringValue = "✅"
            }
        }
    }

    @IBAction func resetKey(_ sender: Any) {
        project?.removeSSHKey()
        project?.settings.gitPrivateKey = nil
        project?.saveSettings()

        keyStatus.stringValue = ""
    }

    public func controlTextDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else { return }

        if textField.identifier?.rawValue == "gitOrigin" {
            project?.settings.setOrigin(textField.stringValue)
            updateButtons()
        }

        if textField.identifier?.rawValue == "gitPassphrase" {
            project?.settings.gitPrivateKeyPassphrase = textField.stringValue
        }

        DispatchQueue.global(qos: .background).async {
            self.project?.saveSettings()
        }
    }

    public func updateButtons(isActive: Bool? = nil) {
        guard let project = project else { return }

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
        self.project = project
        
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
