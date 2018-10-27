//
//  NameTextField.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/9/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class NameTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let status = super.becomeFirstResponder()

        if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
            self.textColor = NSColor.init(named: NSColor.Name(rawValue: "mainText"))
        } else {
            self.textColor = NSColor.black
        }

        return status
    }
}

class TitleBarView: NSView {
    
    var onMouseEnteredClosure: (()->())?
    var onMouseExitedClosure: (()->())?
    
    override func awakeFromNib() {
        
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil))
    }
    
    override func mouseEntered(with event: NSEvent) {
        onMouseEnteredClosure?()
    }
    
    override func mouseExited(with event: NSEvent) {
        onMouseExitedClosure?()
    }
    
}
