//
//  OutlineHeaderView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/21/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class OutlineHeaderView: NSView {

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            if let md = AppDelegate.mainWindowController, let actionOnDoubleClick = UserDefaults.standard.object(forKey: "AppleActionOnDoubleClick") as? String {

                switch actionOnDoubleClick {
                case "Maximize":
                    md.maximizeWindow()
                case "Minimize":
                    md.window?.performMiniaturize(nil)
                default:
                    break
                }
            }
        } else {
            super.mouseDown(with: event)
        }
    }

    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}
