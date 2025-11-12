//
//  ImageAttachment.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/15/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import AVKit

#if os(OSX)
    import Cocoa
#else
    import UIKit
#endif

class NoteAttachment {

    private var path: String

    public var url: URL
    public var title: String
    public var imageCache: URL?

    init(title: String, path: String, url: URL) {
        self.title = title
        self.url = url
        self.path = path
    }

    public static func getSize(url: URL) -> CGSize {
        var width = 0
        var height = 0
        var orientation = 0

        if url.isVideo {
            guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first else {
                return CGSize(width: width, height: height)
            }

            let size = track.naturalSize.applying(track.preferredTransform)
            return CGSize(width: abs(size.width), height: abs(size.height))
        }

        let url = NSURL(fileURLWithPath: url.path)
        if let imageSource = CGImageSourceCreateWithURL(url, nil) {
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary?
            width = imageProperties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            height = imageProperties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            orientation = imageProperties?[kCGImagePropertyOrientation] as? Int ?? 0

            if case 5...8 = orientation {
                height = imageProperties?[kCGImagePropertyPixelWidth] as? Int ?? 0
                width = imageProperties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            }
        }

        return CGSize(width: width, height: height)
    }

    public static func getCacheUrl(from url: URL, prefix: String = "Preview") -> URL? {
        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        temporary.appendPathComponent(prefix)

        return temporary.appendingPathComponent(url.absoluteString.md5 + "." + url.pathExtension)
    }

    public static func savePreviewImage(url: URL, image: Image, prefix: String = "Preview") {
        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        temporary.appendPathComponent(prefix)

        if !FileManager.default.fileExists(atPath: temporary.path) {
            try? FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true, attributes: nil)
        }

        if let url = self.getCacheUrl(from: url, prefix: prefix) {
            if let data = image.jpgData {
                try? data.write(to: url)
            }
        }
    }

    public func getImageText() -> String {
        let fileSize = self.url.fileSize
        var sizeTitle = String()

        if fileSize > 10000 {
            sizeTitle = String(format: "%.2f", Double(fileSize) / 1000000) + " MB"
        } else {
            sizeTitle = String(fileSize) + " bytes"
        }

        let text = " \(self.url.lastPathComponent) – \(sizeTitle) 📎 "
        return text
    }

    public func getImageWidth(text: String) -> Double {
        let font = getAttachmentFont()
        let labelWidth = (text as NSString).size(withAttributes: [.font: font]).width

        return labelWidth
    }

    #if os(OSX)
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

    public static func getSize(width: CGFloat, height: CGFloat) -> NSSize {
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
        let traits = NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(NSFontBoldTrait|NSFontItalicTrait))

        if let font = NSFontManager().font(withFamily: "Avenir Next", traits: traits, weight: 1, size: CGFloat(UserDefaultsManagement.fontSize)) {
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
    #endif

    #if os(iOS)
    public func getAttachmentImage() -> UIImage? {
        let heigth = UserDefaultsManagement.noteFont.getAttachmentHeight()
        let text = getImageText()
        let width = getImageWidth(text: text)
        let imageSize = CGSize(width: width, height: heigth)

        if let image = imageFromText(text: text, imageSize: imageSize) {
            return image
        }

        return nil
    }

    private func getImageSize(imageSize: CGSize) -> CGSize? {
        let controller = UIApplication.getVC()
        let maxWidth = controller.view.frame.width - 35

        guard imageSize.width > maxWidth else {
            return imageSize
        }

        let scale = maxWidth / imageSize.width
        let newHeight = imageSize.height * scale

        return CGSize(width: maxWidth, height: newHeight)
    }

    public static func resize(image: UIImage, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

    public static func getImage(url: URL, size: CGSize) -> UIImage? {
        let imageData = try? Data(contentsOf: url)
        var finalImage: UIImage?

        if url.isVideo {
            let asset = AVURLAsset(url: url, options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            if let cgImage = try? imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil) {
                finalImage = UIImage(cgImage: cgImage)
            }
        } else if let imageData = imageData {
            finalImage = UIImage(data: imageData)
        }

        guard let image = finalImage else { return nil }
        var thumbImage: UIImage?

        if let cacheURL = self.getCacheUrl(from: url, prefix: "ThumbnailsBigInline"), FileManager.default.fileExists(atPath: cacheURL.path) {
            thumbImage = UIImage(contentsOfFile: cacheURL.path)
        } else if
            let resizedImage = self.resize(image: image, size: size) {
            thumbImage = resizedImage
            self.savePreviewImage(url: url, image: resizedImage, prefix: "ThumbnailsBigInline")
        }

        return thumbImage
    }

    public func getAttachmentFont() -> UIFont {
        if let font = UIFont(name: "AvenirNext-BoldItalic", size: CGFloat(UserDefaultsManagement.fontSize)) {
            return font
        }
        return UIFont.systemFont(ofSize: 14.0)
    }

    public func imageFromText(text: String, imageSize: CGSize) -> UIImage? {
        let font = getAttachmentFont()
        let textColor = NotesTextProcessor.fontColor
        let backgroundColor = self.editor?.backgroundColor ?? UIColor.white

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .backgroundColor: backgroundColor,
            .paragraphStyle: paragraphStyle,
        ]

        let textSize = text.size(withAttributes: attributes)
        let imageRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)

        UIGraphicsBeginImageContextWithOptions(imageRect.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        // Fill background color
        backgroundColor.setFill()
        context.fill(imageRect)

        // Draw text
        let textRect = CGRect(x: (imageSize.width - textSize.width) / 2.0, y: (imageSize.height - textSize.height) / 2.0, width: textSize.width, height: textSize.height)
        text.draw(in: textRect, withAttributes: attributes)

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }

        return image
    }
    #endif
}
