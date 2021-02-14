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
        guard let container = ViewController.shared()?.editArea.textContainer else { return nil }

        let attachment = NSTextAttachment()

        let imageSize = getSize(url: self.url)
        var size = self.getSize(width: imageSize.width, height: imageSize.height)

        if url.isImage {
            let cell = FSNTextAttachmentCell(textContainer: container, image: NSImage(size: size))
            cell.image?.size = size
            attachment.image = nil
            attachment.attachmentCell = cell
            attachment.bounds = NSRect(x: 0, y: 0, width: size.width, height: size.height)

        } else {
            size = NSSize(width: 35, height: 35)

            if let image = NSImage(named: "file") {
                let cell = FSNTextAttachmentCell(textContainer: container, image: image)
                cell.image?.size = size
                attachment.image = nil
                attachment.attachmentCell = cell
                attachment.bounds = NSRect(x: 0, y: 0, width: size.width, height: size.height)
            }
        }

        return attachment
    }

    private func getEditorView() -> EditTextView? {
        if let cvc = ViewController.shared(), let view = cvc.editArea {
            return view
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
}
