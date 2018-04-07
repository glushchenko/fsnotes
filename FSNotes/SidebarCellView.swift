//
//  SidebarCellView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class SidebarCellView: NSTableCellView {
    @IBOutlet weak var icon: NSImageView!
    @IBOutlet weak var label: NSTextField!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let si = objectValue as? SidebarItem else {
            return
        }
        
        switch si.type {
        case .All:
            if let image = NSImage.init(named: .homeTemplate) {
                icon.image = image
            }
        case .Trash:
            if let image = NSImage.init(named: .trashFull) {
                icon.image = image
                //print(icon)
            }
        case .Label:
            icon.isHidden = true
            label.frame.origin.x = 5
        default:
            if let image = NSImage.init(named: .pathTemplate) {
                icon.image = image
                //print(icon)
            }
            break
        }
    }
}
