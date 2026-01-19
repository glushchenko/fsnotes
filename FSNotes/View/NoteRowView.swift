//
//  NoteRowView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/31/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class NoteRowView: NSTableRowView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override func drawSeparator(in dirtyRect: NSRect) {
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
