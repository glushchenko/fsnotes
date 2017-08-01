//
//  NoteCellView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/31/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class NoteCellView: NSTableCellView {

    @IBOutlet weak var name: NSTextField!
    @IBOutlet weak var preview: NSTextField!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let font = NSFont(name: "Source Code Pro", size: 11)
        //name.font = font
        preview.font = font
        
        
    }
}
