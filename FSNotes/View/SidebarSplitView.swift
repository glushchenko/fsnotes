//
//  SidebarSplitView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class SidebarSplitView: NSSplitView {
    override var dividerColor: NSColor {
        return NSColor.init(named: "divider")!
    }
}

