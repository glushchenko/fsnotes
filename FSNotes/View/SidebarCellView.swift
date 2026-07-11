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

    private var countLabel: NSTextField?

    public func updateCount(_ count: Int?) {
        guard let count = count, UserDefaultsManagement.showNoteCountsInSidebar else {
            // Do not create the label (and its constraints) for cells that
            // never showed a count — just reset reused ones.
            countLabel?.stringValue = ""
            countLabel?.isHidden = true
            return
        }

        let field = countLabel ?? createCountLabel()
        field.stringValue = String(count)
        field.isHidden = false
    }

    private func createCountLabel() -> NSTextField {
        let field = NSTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.alignment = .right
        field.font = NSFont.systemFont(ofSize: 11)
        field.textColor = .secondaryLabelColor
        field.lineBreakMode = .byClipping

        field.setContentHuggingPriority(.required, for: .horizontal)
        field.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(field)

        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            field.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            field.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 4)
        ])

        countLabel = field
        return field
    }

    @IBAction func projectName(_ sender: NSTextField) {
        let cell = sender.superview as? SidebarCellView

        guard let project = cell?.objectValue as? Project else { return }
        
        let src = project.url
        let dst = project.url.deletingLastPathComponent().appendingPathComponent(sender.stringValue, isDirectory: true)

        do {
            if FileManager.default.fileExists(atPath: dst.path) {
                sender.stringValue = project.url.lastPathComponent
                return
            }

            try FileManager.default.moveItem(at: src, to: dst)
        } catch {
            sender.stringValue = project.url.lastPathComponent
            let alert = NSAlert()
            alert.messageText = error.localizedDescription
            alert.runModal()
        }
    }
}
