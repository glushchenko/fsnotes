//
//  OutlineHeaderView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/21/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class OutlineHeaderView: NSView {
    private var lastWindowSize: NSRect? = nil

    override func mouseDown(with event: NSEvent) {
        let currentSize = window?.frame

        if event.clickCount == 2 {
            if let screen = NSScreen.main {
                let size = lastWindowSize ?? screen.visibleFrame
                window?.setFrame(size, display: true, animate: true)

                if lastWindowSize == nil {
                    lastWindowSize = currentSize
                } else {
                    lastWindowSize = nil
                }
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
       super.draw(dirtyRect)

       let lightColor = NSColor(red:1.00, green:1.00, blue:1.00, alpha:1.0)
       let darkColor = NSColor(red:0.16, green:0.17, blue:0.18, alpha:1.0)

       if NSAppearance.current.isDark {
          darkColor.setFill()
       } else {
          lightColor.setFill()
       }

       dirtyRect.fill()
    }
}
