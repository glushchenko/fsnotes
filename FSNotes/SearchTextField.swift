//
//  SearchTextField.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/3/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class SearchTextField: NSTextField {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override func keyUp(with event: NSEvent) {
        if (event.keyCode == 125) {
            let viewController = self.window?.contentViewController as? ViewController
            viewController?.focusTable()
        }
    }
    
}
