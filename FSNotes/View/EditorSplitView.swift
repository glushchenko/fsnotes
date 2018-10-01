//
//  EditorSplitView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class EditorSplitView: NSSplitView, NSSplitViewDelegate {
    override func draw(_ dirtyRect: NSRect) {
        self.delegate = self
        super.draw(dirtyRect)
    }
    
    override func maxPossiblePositionOfDivider(at dividerIndex: Int) -> CGFloat {
        return 250
    }
    
    override var dividerColor: NSColor {
        if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
            return NSColor.init(named: NSColor.Name(rawValue: "divider"))!
        } else {
            return NSColor(red:0.83, green:0.83, blue:0.83, alpha:1.0)
        }
    }
}
