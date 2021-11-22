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

    public var type: SidebarItemType?
    public var storage = Storage.sharedInstance()

    @IBAction func projectName(_ sender: NSTextField) {
        let cell = sender.superview as? SidebarCellView

        guard let project = cell?.objectValue as? Project else { return }

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

    override var backgroundStyle: NSView.BackgroundStyle {
        set {
            applyBackgroundAndTextColors()
        }
        get {
            return super.backgroundStyle;
        }
    }

    public func applyBackgroundAndTextColors() {
        guard let rowView = self.superview as? SidebarTableRowView else { return }

        if rowView.isSelected {

            // first responder

            if window?.firstResponder == superview?.superview {
                applySelectedFirstResponder()

            // no first responder

            } else {
                label.textColor = NSColor(named: "color_selected_not_fr")
                icon.image = type?.getIcon()
                rowView.backgroundColor = NSColor(named: "background_selected_not_fr")!
            }

        // not selected

        } else {
            label.textColor = NSColor(named: "color_not_selected")
            icon.image = type?.getIcon()
            rowView.backgroundColor = NSColor(named: "background_not_selected")!
        }
    }

    public func applySelectedFirstResponder() {
        label.textColor = .white
        icon.image = type?.getIcon(white: true)

        guard let rowView = self.superview as? SidebarTableRowView else { return }
        rowView.backgroundColor = NSColor(named: "background_selected_fr")!
    }
}
