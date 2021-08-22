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
    
    override func drawSelection(in dirtyRect: NSRect) {
        guard UserDefaults.standard.value(forKey: "AppleAccentColor") == nil else {
            super.drawSelection(in: dirtyRect)
            return
        }
        
        if self.selectionHighlightStyle != .none {
            let selectionRect = NSInsetRect(self.bounds, 0, 0)

            if isSelected {
                if window?.firstResponder == superview {

                    if let color = NSColor.init(named: "background_selected_fr") {
                        color.setStroke()
                        color.setFill()
                    }

                    let selectionPath = NSBezierPath.init(roundedRect: selectionRect, xRadius: 2, yRadius: 2)
                    selectionPath.fill()
                    selectionPath.stroke()

                } else {

                    if let color = NSColor.init(named: "background_selected_not_fr") {
                        color.setStroke()
                        color.setFill()
                    }

                    let selectionPath = NSBezierPath.init(roundedRect: selectionRect, xRadius: 2, yRadius: 2)
                    selectionPath.fill()
                    selectionPath.stroke()
                }
            }
        }
    }
}
