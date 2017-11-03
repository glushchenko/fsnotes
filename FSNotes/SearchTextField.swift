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
        // Down arrow
        if (event.keyCode == 125) {
            let viewController = self.window?.contentViewController as? ViewController
            viewController?.focusTable()
        }
    }
 
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if (
            event.keyCode == 53
            || (
                [37, 45].contains(event.keyCode)
                && event.modifierFlags.contains(NSEvent.ModifierFlags.command)
            )
        ) {
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }

}
