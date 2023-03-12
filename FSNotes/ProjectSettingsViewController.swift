//
//  ProjectSettingsViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 11/23/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Carbon.HIToolbox

class ProjectSettingsViewController: NSViewController {
    
    private var project: Project?
    
    @IBOutlet weak var modificationDate: NSButton!
    @IBOutlet weak var creationDate: NSButton!
    @IBOutlet weak var titleButton: NSButton!
    @IBOutlet weak var sortByGlobal: NSButton!
    @IBOutlet weak var directionASC: NSButton!
    @IBOutlet weak var directionDESC: NSButton!
    @IBOutlet weak var showInAll: NSButton!
    @IBOutlet weak var firstLineAsTitle: NSButton!
    @IBOutlet weak var nestedFoldersContent: NSButton!
    @IBOutlet weak var origin: NSTextField!

    @IBAction func sortBy(_ sender: NSButton) {
        guard let project = project else { return }
        
        let sortBy = SortBy(rawValue: sender.identifier!.rawValue)!
        if sortBy != .none {
            project.settings.sortBy = sortBy
        }
        
        project.settings.sortBy = sortBy
        project.saveSettings()
        
        guard let vc = ViewController.shared() else { return }
        vc.updateTable()
    }
    
    @IBAction func sortDirection(_ sender: NSButton) {
        guard let project = project else { return }
        
        project.settings.sortDirection = SortDirection(rawValue: sender.identifier!.rawValue)!
        project.saveSettings()
        
        guard let vc = ViewController.shared() else { return }
        vc.updateTable()
    }
    
    
    @IBAction func showNotesInMainList(_ sender: NSButton) {
        project?.settings.showInCommon = sender.state == .on
        project?.saveSettings()
    }
    
    @IBAction func firstLineAsTitle(_ sender: NSButton) {
        guard let project = self.project else { return }
        
        project.settings.firstLineAsTitle = sender.state == .on
        project.saveSettings()
        
        let notes = Storage.shared().getNotesBy(project: project)
        for note in notes {
            note.invalidateCache()
        }
        
        guard let vc = ViewController.shared() else { return }
        vc.notesTableView.reloadData()
    }
    
    @IBAction func close(_ sender: Any) {
        self.dismiss(nil)
    }
    
    @IBAction func showNestedFoldersContent(_ sender: NSButton) {
        guard let project = self.project else { return }
        
        project.settings.showNestedFoldersContent = sender.state == .on
        project.saveSettings()
        
        guard let vc = ViewController.shared() else { return }
        vc.updateTable()
    }
    
    @IBAction func origin(_ sender: NSTextField) {
        guard let project = self.project else { return }

        project.settings.setOrigin(sender.stringValue)
        project.saveSettings()

        if project.isDefault {
            UserDefaultsManagement.gitOrigin = sender.stringValue
        }
    }
    
    @IBAction func clonePull(_ sender: Any) {
        guard let project = self.project else { return }
        guard let window = view.window else { return }

        let origin = self.origin.stringValue
        project.settings.setOrigin(origin)
        project.saveSettings()
        
        ProjectSettingsViewController.cloneAndPull(origin: origin, project: project, window: window)
    }
    
    public static func cloneAndPull(origin: String, project: Project, window: NSWindow) {
        guard origin.count > 3 else {
            let alert = NSAlert()
            alert.messageText = "Origin is empty"
            alert.alertStyle = .critical
            alert.informativeText = "Configure origin at first!"
            alert.runModal()
            return
        }
        
        let password = UserDefaultsManagement.gitPassword ?? ""
        let username = UserDefaultsManagement.gitUsername ?? ""
        
        if origin.startsWith(string: "git") && (password.count > 0 || username.count > 0) {
            let alert = NSAlert()
            alert.messageText = "Wrong configuration"
            alert.alertStyle = .critical
            alert.informativeText = "You cannot use Username and Password with git@ origin, please use private key"
            alert.runModal()
            return
        }
        
        if origin.startsWith(string: "https") && (password.count == 0 || username.count == 0) {
            let alert = NSAlert()
            alert.messageText = "Wrong configuration"
            alert.alertStyle = .critical
            alert.informativeText = "Please fill Username and Password for https:// origin"
            alert.runModal()
            return
        }
        
        if project.hasRepository() {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Git repository already exists, delete it and clone again??", comment: "")
            alert.informativeText = NSLocalizedString("This action cannot be undone.", comment: "")
            alert.addButton(withTitle: NSLocalizedString("Yes", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("No", comment: ""))
            alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    do {
                        project.removeRepository()
                        
                        ProjectSettingsViewController.cloneAndPull(project: project)
                    } catch {/*_*/}
                }
            }
            return
        }
        
        ProjectSettingsViewController.cloneAndPull(project: project)
    }
    
    public static func cloneAndPull(project: Project) {
        do {
            if let repo = try project.cloneRepository(),
                let local = project.getLocalBranch(repository: repo)
            {
                try repo.head().forceCheckout(branch: local)
            }
            return
        } catch GitError.unknownError(let errorMessage, _, let desc){
            let alert = NSAlert()
            alert.messageText = "Git clone/pull error"
            alert.alertStyle = .critical
            alert.informativeText = String("\(errorMessage) –  \(desc)")
            alert.runModal()
        } catch GitError.notFound(let ref) {
            // Empty repository – commit and push
            if ref == "refs/heads/master" {
                try? project.commit()
                try? project.push()
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.informativeText = NSLocalizedString("Git error", comment: "")
            alert.messageText = error.localizedDescription
            alert.runModal()
        }
    }
    
    public static func askForceCheckout(project: Project, window: NSWindow) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Do you want force checkout?", comment: "")
        alert.informativeText = NSLocalizedString("This action cannot be undone.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Yes", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("No", comment: ""))
        alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                if let repo = try? project.getRepository(), let local = project.getLocalBranch(repository: repo) {
                    do {
                        try repo.head().forceCheckout(branch: local)
                    } catch {
                        print("Checkout: \(error)")
                    }
                }
            }
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Return || event.keyCode == kVK_Escape {
            self.dismiss(nil)
        }
    }

    public func load(project: Project) {
        showInAll.state = project.settings.showInCommon ? .on : .off
        firstLineAsTitle.state = project.settings.firstLineAsTitle ? .on : .off
        nestedFoldersContent.state = project.settings.showNestedFoldersContent ? .on : .off

        modificationDate.state = project.settings.sortBy == .modificationDate ? .on : .off
        creationDate.state = project.settings.sortBy == .creationDate ? .on : .off
        titleButton.state = project.settings.sortBy == .title ? .on : .off
        sortByGlobal.state = project.settings.sortBy == .none ? .on : .off

        directionASC.state = project.settings.sortDirection == .asc ? .on : .off
        directionDESC.state = project.settings.sortDirection == .desc ? .on : .off
        
        origin.stringValue = project.settings.gitOrigin ?? ""
        self.project = project
    }
    
//    public static func saveSettings() {
//        var result = [URL: Data]()
//
//        let projects = Storage.shared().getProjects()
//        for project in projects {
//            if let data = project.settingsList {
//                result[project.url] = data
//            }
//        }
//
//        if result.count > 0 {
//            let projectsData = try? NSKeyedArchiver.archivedData(withRootObject: result, requiringSecureCoding: false)
//            if let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
//                try? projectsData?.write(to: documentDir.appendingPathComponent("projects.settings"))
//            }
//        }
//    }
    
//    public static func restoreSettings() {
//        guard let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
//
//        let projectsDataUrl = documentDir.appendingPathComponent("projects.settings")
//        guard let data = try? Data(contentsOf: projectsDataUrl) else { return }
//
//        guard let unarchivedData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [URL: Data] else { return }
//
//        for item in unarchivedData {
//            if let project = Storage.shared().getProjectBy(url: item.key) {
//                project.settingsList = item.value
//                project.loadSettings()
//            }
//        }
//    }
}
