//
//  PreviewTextField.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/28/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PreviewTextField: NSTextField {
    override var intrinsicContentSize: NSSize {
        let width = super.intrinsicContentSize.width
        let height = maximumNumberOfLines * 13
        return NSSize(width: width, height: CGFloat(height))
    }
}
