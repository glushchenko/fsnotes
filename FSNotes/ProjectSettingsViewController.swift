//
//  ProjectSettingsViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 11/23/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Carbon.HIToolbox

class ProjectSettingsViewController: SettingsViewController {

    @IBOutlet weak var modificationDate: NSButton!
    @IBOutlet weak var creationDate: NSButton!
    @IBOutlet weak var titleButton: NSButton!
    @IBOutlet weak var sortByGlobal: NSButton!
    @IBOutlet weak var directionASC: NSButton!
    @IBOutlet weak var directionDESC: NSButton!
    @IBOutlet weak var showInAll: NSButton!
    @IBOutlet weak var firstLineAsTitle: NSButton!
    @IBOutlet weak var nestedFoldersContent: NSButton!

    @IBAction func sortBy(_ sender: NSButton) {
        guard let project = project else { return }
        
        let sortBy = SortBy(rawValue: sender.identifier!.rawValue)!
        if sortBy != .none {
            project.settings.sortBy = sortBy
        }
        
        project.settings.sortBy = sortBy
        project.saveSettings()
        
        guard let vc = ViewController.shared() else { return }

        vc.buildSearchQuery()
        vc.updateTable()
    }
    
    @IBAction func sortDirection(_ sender: NSButton) {
        guard let project = project else { return }
        
        project.settings.sortDirection = SortDirection(rawValue: sender.identifier!.rawValue)!
        project.saveSettings()
        
        guard let vc = ViewController.shared() else { return }

        vc.buildSearchQuery()
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

    public func load(project: Project) {
        if project.isVirtual {
            showInAll.isEnabled = false
            nestedFoldersContent.isEnabled = false
            firstLineAsTitle.isEnabled = false
        }

        showInAll.state = project.settings.showInCommon ? .on : .off
        firstLineAsTitle.state = project.settings.isFirstLineAsTitle() ? .on : .off
        nestedFoldersContent.state = project.settings.showNestedFoldersContent ? .on : .off

        modificationDate.state = project.settings.sortBy == .modificationDate ? .on : .off
        creationDate.state = project.settings.sortBy == .creationDate ? .on : .off
        titleButton.state = project.settings.sortBy == .title ? .on : .off
        sortByGlobal.state = project.settings.sortBy == .none ? .on : .off

        directionASC.state = project.settings.sortDirection == .asc ? .on : .off
        directionDESC.state = project.settings.sortDirection == .desc ? .on : .off

        loadGit(project: project)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Return || event.keyCode == kVK_Escape {
            self.dismiss(nil)
        }
    }
}
