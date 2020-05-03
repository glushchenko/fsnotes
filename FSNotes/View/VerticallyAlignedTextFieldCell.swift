//
//  VerticallyAlignedTextFieldCell.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 03.05.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class VerticallyAlignedTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let newRect = NSRect(x: 0, y: (rect.size.height - 22) / 2, width: rect.size.width, height: 22)
        return super.drawingRect(forBounds: newRect)
    }
}
