//
//  SidebarTableRowView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/11/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class SidebarTableRowView: NSTableRowView {
    // Use AppKit's neutral selection even when the sidebar has keyboard focus.
    override var isEmphasized: Bool {
        get { false }
        set { }
    }
}
