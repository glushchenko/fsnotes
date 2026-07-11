//
//  NoteRowView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/31/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class NoteRowView: NSTableRowView {
    private var isMiniPreview: Bool {
        return UserDefaultsManagement.miniPreview && !UserDefaultsManagement.horizontalOrientation
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    // MiniPreview shows selection as an accent border on the card, like
    // Apple Notes; the full-row highlight and separators are skipped.
    override func drawSelection(in dirtyRect: NSRect) {
        if isMiniPreview {
            return
        }

        super.drawSelection(in: dirtyRect)
    }

    override func drawSeparator(in dirtyRect: NSRect) {
        if isMiniPreview {
            return
        }
        let leftInset: CGFloat = 23
        let rightInset: CGFloat = 15
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let pixel = 1.0 / scale

        let y = floor(bounds.height - pixel)
        let w = max(0, bounds.width - leftInset - rightInset)

        NSColor.separatorColor.setFill()
        NSBezierPath(rect: NSRect(x: leftInset, y: y, width: w, height: pixel)).fill()
    }
}
