//
//  HyperlinkTextField.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 13.11.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

@IBDesignable
class HyperlinkTextField: NSTextField {
    @IBInspectable var href: String = ""

    override func awakeFromNib() {
        super.awakeFromNib()

        let attributes: [NSAttributedString.Key : Any] = [
            NSAttributedString.Key.foregroundColor: NSColor.blue,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single
        ]
        
        self.attributedStringValue = NSAttributedString(string: self.stringValue, attributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        NSWorkspace.shared.open(URL(string: self.href)!)
    }
}
