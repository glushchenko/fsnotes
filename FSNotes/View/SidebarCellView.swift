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
    public var storage = Storage.shared()

    @IBAction func projectName(_ sender: NSTextField) {
        let cell = sender.superview as? SidebarCellView

        guard let project = cell?.objectValue as? Project else { return }
        
        let src = project.url
        let dst = project.url.deletingLastPathComponent().appendingPathComponent(sender.stringValue, isDirectory: true)

        do {
            try FileManager.default.moveItem(at: src, to: dst)
        } catch {
            sender.stringValue = project.url.lastPathComponent
            let alert = NSAlert()
            alert.messageText = error.localizedDescription
            alert.runModal()
        }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        set {
            guard let rowView = self.superview as? NSTableRowView else { return }
            
            if !rowView.isSelected {
                icon.image = type?.getIcon()
            }

            if window?.firstResponder == superview?.superview {
                applySelectedFirstResponder()
            } else {
                icon.image = type?.getIcon()
            }
        }
        get {
            return super.backgroundStyle;
        }
    }

    public func applySelectedFirstResponder() {
        icon.image = type?.getIcon(white: true)
    }
}
