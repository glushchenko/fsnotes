//
//  SidebarHeaderCellView.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 15.10.2019.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class SidebarHeaderCellView: NSTableCellView {
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var icon: NSImageView!

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
                rowView.backgroundColor = NSColor(named: "background_selected_not_fr")!
            }

        // not selected

        } else {
            label.textColor = .gray
            rowView.backgroundColor = NSColor(named: "background_not_selected")!
        }
    }

    public func applySelectedFirstResponder() {
        label.textColor = .white

        guard let rowView = self.superview as? SidebarTableRowView else { return }
        rowView.backgroundColor = NSColor(named: "background_selected_fr")!
    }
}
