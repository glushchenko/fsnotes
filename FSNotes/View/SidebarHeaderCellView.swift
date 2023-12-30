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
        }
        get {
            return super.backgroundStyle;
        }
    }
}
