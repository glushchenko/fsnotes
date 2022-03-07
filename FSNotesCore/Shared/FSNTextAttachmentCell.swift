//
//  FSNTextAttachmentCell.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 25.11.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class FSNTextAttachmentCell: NSTextAttachmentCell {
    let textContainer: NSTextContainer

    init(textContainer: NSTextContainer, image: NSImage) {
        self.textContainer = textContainer
        super.init(imageCell: image)
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func cellSize() -> NSSize {
        let size = super.cellSize()

        if size.height == 35 {
            return size
        }

        return NSSize(width: textContainer.size.width, height: size.height)
    }
}
