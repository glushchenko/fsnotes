//
//  ImageAttachment+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/19/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import AVKit

extension NoteAttachment {
    public func load() -> NSTextAttachment? {
        guard let container = self.editor?.textContainer else { return nil }

        let attachment = NSTextAttachment()

        // Image attachment

        if url.isImage {
            let imageSize = getSize(url: self.url)
            let size = self.getSize(width: imageSize.width, height: imageSize.height)
            let cell = FSNTextAttachmentCell(textContainer: container, image: NSImage(size: size))
            cell.image?.size = size
            attachment.image = nil
            attachment.attachmentCell = cell
            attachment.bounds = NSRect(x: 0, y: 0, width: size.width, height: size.height)

            return attachment
        }

        // File attachment

        let heigth = UserDefaultsManagement.noteFont.getAttachmentHeight()
        let text = getImageText()
        let width = getImageWidth(text: text)
        let size = NSSize(width: width, height: heigth)
        let imageSize = NSSize(width: width, height: heigth)

        if let image = imageFromText(text: text, imageSize: imageSize) {
            let cell = FSNTextAttachmentCell(textContainer: container, image: image)
            cell.image?.size = size
            attachment.image = nil
            attachment.attachmentCell = cell
            attachment.bounds = NSRect(x: 0, y: 0, width: size.width, height: size.height)
            return attachment
        }

        return nil
    }

    public func getAttachmentImage() -> NSImage? {
        let heigth = UserDefaultsManagement.noteFont.getAttachmentHeight()
        let text = getImageText()
        let width = getImageWidth(text: text)
        let imageSize = NSSize(width: width, height: heigth)

        if let image = imageFromText(text: text, imageSize: imageSize) {
            return image
        }

        return nil
    }

    public func getSize(width: CGFloat, height: CGFloat) -> NSSize {
        var maxWidth = UserDefaultsManagement.imagesWidth

        if maxWidth == Float(1000) {
            maxWidth = Float(width)
        }

        let ratio: Float = Float(maxWidth) / Float(width)
        var size = NSSize(width: Int(width), height: Int(height))

        if ratio < 1 {
            size = NSSize(width: Int(maxWidth), height: Int(Float(height) * Float(ratio)))
        }

        return size
    }

    public static func getImage(url: URL, size: CGSize) -> NSImage? {
        let imageData = try? Data(contentsOf: url)
        var finalImage: NSImage?

        if url.isVideo {
            let asset = AVURLAsset(url: url, options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            if let cgImage = try? imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil) {
                finalImage = NSImage(cgImage: cgImage, size: size)
            }
        } else if let imageData = imageData {
            finalImage = NSImage(data: imageData)
        }

        guard let image = finalImage else { return nil }
        var thumbImage: NSImage?
        thumbImage = finalImage

        if let cacheURL = self.getCacheUrl(from: url, prefix: "ThumbnailsBig"), FileManager.default.fileExists(atPath: cacheURL.path) {
            thumbImage = NSImage(contentsOfFile: cacheURL.path)
        } else if
            let resizedImage = image.resized(to: size) {
            thumbImage = resizedImage

            self.savePreviewImage(url: url, image: resizedImage, prefix: "ThumbnailsBig")
        }

        return thumbImage
    }

    public func getAttachmentFont() -> NSFont {
        if let font = NSFontManager().font(withFamily: "Avenir Next", traits: NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(NSFontBoldTrait|NSFontItalicTrait)), weight: 1, size: CGFloat(UserDefaultsManagement.fontSize)) {
            return font
        }

        return NSFont.systemFont(ofSize: 14.0)
    }

    public func imageFromText(text: String, imageSize: NSSize) -> NSImage? {
        let font = getAttachmentFont()
        
        let textColor =  UserDataService.instance.isDark ? NSColor.white : NSColor.black
        let backgroundColor = UserDataService.instance.isDark ? NSColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1.00) : NSColor.white

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.backgroundColor: backgroundColor,
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
        ]

        let textSize = text.size(withAttributes: attributes)
        let imageRect = NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)

        let image = NSImage(size: imageRect.size)
        image.lockFocus()

        // Fill background color
        backgroundColor.setFill()
        imageRect.fill()

        // Draw text
        let textRect = NSRect(x: (imageSize.width - textSize.width) / 2.0, y: (imageSize.height - textSize.height) / 2.0, width: textSize.width, height: textSize.height)
        text.draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()

        return image
    }
}
