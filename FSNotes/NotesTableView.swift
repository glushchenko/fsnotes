//
//  NotesTableView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/31/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class NotesTableView: NSTableView {

    var notesList = [Note]()
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override func keyDown(with event: NSEvent) {
        // backspace
        if (event.keyCode == 51) {
            
        }
    }
    
    
    
}
