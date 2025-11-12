//
//  NSTextStorage+.swift
//  FSNotesCore macOS
//
//  Created by Oleksandr Glushchenko on 7/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

import Cocoa

extension NSTextStorage {
    public func sizeAttachmentImages(container: NSTextContainer) {
        return
        
        enumerateAttribute(.fsAttachment, in: NSRange(location: 0, length: self.length)) { (value, range, _) in
            guard let attachment = attribute(.attachment, at: range.location, effectiveRange: nil) as? NSTextAttachment else { return }

            if let imageData = attachment.fileWrapper?.regularFileContents,
               var image = NSImage(data: imageData),
               let rep = image.representations.first {

                var maxWidth = UserDefaultsManagement.imagesWidth
                if maxWidth == Float(1000) {
                    maxWidth = Float(rep.pixelsWide)
                }

                let ratio: Float = Float(maxWidth) / Float(rep.pixelsWide)
                var size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)

                if ratio < 1 {
                    size = NSSize(width: Int(maxWidth),
                                  height: Int(Float(rep.pixelsHigh) * ratio))
                }

                image = image.resize(to: size)!
                attachment.bounds = CGRect(origin: .zero, size: size)

                let cell = FSNTextAttachmentCell(textContainer: container, image: image)
                attachment.attachmentCell = cell

                addAttribute(.link, value: String(), range: range)
            }
        }
    }
}
