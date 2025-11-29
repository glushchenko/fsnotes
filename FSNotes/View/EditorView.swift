//
//  EditorView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class EditorView: NSView {
    override func mouseDown(with event: NSEvent) {
        guard let vc = ViewController.shared() else { return }
        vc.editor.mouseDown(with: event)

        NSApp.mainWindow?.makeFirstResponder(vc.editor)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor(named: "mainBackground")!.setFill()
        __NSRectFill(dirtyRect)
    }
}
