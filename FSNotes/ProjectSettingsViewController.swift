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
            project.sortBy = sortBy
        }

        project.sortBy = sortBy
        project.saveSettings()

        guard let vc = ViewController.shared() else { return }
        vc.updateTable()
    }

    @IBAction func sortDirection(_ sender: NSButton) {
        guard let project = project else { return }

        project.sortDirection = SortDirection(rawValue: sender.identifier!.rawValue)!
        project.saveSettings()

        guard let vc = ViewController.shared() else { return }
        vc.updateTable()
    }


    @IBAction func showNotesInMainList(_ sender: NSButton) {
        project?.showInCommon = sender.state == .on
        project?.saveSettings()
    }

    @IBAction func firstLineAsTitle(_ sender: NSButton) {
        guard let project = self.project else { return }

        project.firstLineAsTitle = sender.state == .on
        project.saveSettings()

        let notes = Storage.sharedInstance().getNotesBy(project: project)
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

        project.showNestedFoldersContent = sender.state == .on
        project.saveSettings()

        guard let vc = ViewController.shared() else { return }
        vc.updateTable()
    }
    
    @IBAction func origin(_ sender: NSTextField) {
        guard let project = self.project else { return }

        project.gitOrigin = sender.stringValue
        project.saveSettings()
    }
    

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Return || event.keyCode == kVK_Escape {
            self.dismiss(nil)
        }
    }

    public func load(project: Project) {
        showInAll.state = project.showInCommon ? .on : .off
        firstLineAsTitle.state = project.firstLineAsTitle ? .on : .off
        nestedFoldersContent.state = project.showNestedFoldersContent ? .on : .off

        modificationDate.state = project.sortBy == .modificationDate ? .on : .off
        creationDate.state = project.sortBy == .creationDate ? .on : .off
        titleButton.state = project.sortBy == .title ? .on : .off
        sortByGlobal.state = project.sortBy == .none ? .on : .off

        directionASC.state = project.sortDirection == .asc ? .on : .off
        directionDESC.state = project.sortDirection == .desc ? .on : .off

        origin.stringValue = project.gitOrigin ?? ""
        
        self.project = project
        
        
        project.loadSettings()
    }
    
    public static func saveSettings() {
        var result = [URL: Data]()
        
        let projects = Storage.sharedInstance().getProjects()
        for project in projects {
            if let data = project.settingsList {
                result[project.url] = data
            }
        }
        
        if result.count > 0 {
            let projectsData = try? NSKeyedArchiver.archivedData(withRootObject: result, requiringSecureCoding: false)
            if let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? projectsData?.write(to: documentDir.appendingPathComponent("projects.settings"))
            }
        }
    }
    
    public static func restoreSettings() {
        guard let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
 
        let projectsDataUrl = documentDir.appendingPathComponent("projects.settings")
        guard let data = try? Data(contentsOf: projectsDataUrl) else { return }
        
        guard let unarchivedData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [URL: Data] else { return }
        
        for item in unarchivedData {
            if let project = Storage.sharedInstance().getProjectBy(url: item.key) {
                project.settingsList = item.value
                project.loadSettings()
            }
        }
    }
}
