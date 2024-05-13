//
//  ImageAttachment+.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/19/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVKit

extension NoteAttachment {
    public func load() -> NSTextAttachment? {
        let attachment = NSTextAttachment()

        if (url.isImage) {
            let imageSize = getSize(url: self.url)
            guard let size = getImageSize(imageSize: imageSize) else { return nil }

            attachment.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            attachment.image = UIImage.emptyImage(with: size)

            return attachment
        }

        // File attachment

        let heigth = UserDefaultsManagement.noteFont.getAttachmentHeight()
        let text = getImageText()
        let width = getImageWidth(text: text)
        let size = CGSize(width: width, height: heigth)
        let imageSize = CGSize(width: width, height: heigth)

        if let image = imageFromText(text: text, imageSize: imageSize) {
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            return attachment
        }

        return nil
    }

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
}
