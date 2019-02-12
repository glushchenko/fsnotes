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

    @IBOutlet weak var showInAll: NSButton!
    @IBOutlet weak var firstLineAsTitle: NSButton!

    @IBAction func sortBy(_ sender: NSButton) {
        project?.sortBy = SortBy(rawValue: sender.identifier!.rawValue)!
        project?.saveSettings()

        guard let vc = ViewController.shared() else {
            return
        }

        vc.updateTable()
    }

    @IBAction func showNotesInMainList(_ sender: NSButton) {
        project?.showInCommon = sender.state == .on
        project?.saveSettings()
    }

    @IBAction func firstLineAsTitle(_ sender: NSButton) {
        project?.firstLineAsTitle = sender.state == .on
        project?.saveSettings()
    }

    @IBAction func close(_ sender: Any) {
        self.dismiss(nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Return || event.keyCode == kVK_Escape {
            self.dismiss(nil)
        }
    }

    public func load(project: Project) {
        showInAll.state = project.showInCommon ? .on : .off
        firstLineAsTitle.state = project.firstLineAsTitle ? .on : .off

        modificationDate.state = project.sortBy == .modificationDate ? .on : .off
        creationDate.state = project.sortBy == .creationDate ? .on : .off
        titleButton.state = project.sortBy == .title ? .on : .off

        self.project = project
    }
}
