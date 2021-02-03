//
//  SidebarCellView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class SidebarCellView: NSTableCellView {
    @IBOutlet weak var icon: NSImageView!
    @IBOutlet weak var label: NSTextField!
    
    var storage = Storage.sharedInstance()

    @IBAction func projectName(_ sender: NSTextField) {
        let cell = sender.superview as? SidebarCellView
        guard let si = cell?.objectValue as? SidebarItem, let project = si.project else { return }

        let src = project.url
        let dst = project.url.deletingLastPathComponent().appendingPathComponent(sender.stringValue, isDirectory: true)

        project.url = dst
        project.loadLabel()

        project.moveSrc = src
        project.moveDst = dst

        do {
            try FileManager.default.moveItem(at: src, to: dst)
        } catch {
            sender.stringValue = project.url.lastPathComponent
            let alert = NSAlert()
            alert.messageText = error.localizedDescription
            alert.runModal()
        }

        storage.unload(project: project)
        storage.loadLabel(project)

        guard let vc = self.window?.contentViewController as? ViewController else { return }
        vc.fsManager?.restart()
        vc.loadMoveMenu()
        
        vc.updateTable()
    }
}
