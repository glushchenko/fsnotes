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

        self.textColor = NSColor.init(named: "mainText")?
            .withAlphaComponent(CGFloat(UserDefaultsManagement.notesListTextBrightness))

        return status
    }
}
