//
//  CustomTextStorage+Images.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 9/21/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import AVKit

extension NSTextStorage {
    public func loadImage(attachment: NSTextAttachment, url: URL, range: NSRange) {
        EditTextView.imagesLoaderQueue.addOperation {
            guard url.isImage, let size = attachment.image?.size else { return }

            let image = NoteAttachment.getImage(url: url, size: size)?.resize(to: size)?.roundCorners(withRadius: 3)

            DispatchQueue.main.async {
                let cell = NSTextAttachmentCell(imageCell: image)
                attachment.image = nil
                attachment.attachmentCell = cell

                if let manager = ViewController.shared()?.editArea.layoutManager {
                    manager.invalidateDisplay(forCharacterRange: range)
                    manager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                }
            }
        }
    }
}
