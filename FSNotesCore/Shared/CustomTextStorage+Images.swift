//
//  CustomTextStorage+Images.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 9/21/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

#if os(OSX)
import AppKit
#else
import UIKit
#endif

import AVKit

extension NSTextStorage {

    public func loadImage(attachment: NSTextAttachment, url: URL, range: NSRange) {
        EditTextView.imagesLoaderQueue.addOperation {
            guard let size = attachment.image?.size else { return }

            attachment.image = self.getImage(url: url, size: size)

            DispatchQueue.main.async {
                let manager = UIApplication.getEVC().editArea.layoutManager as NSLayoutManager

                manager.invalidateDisplay(forCharacterRange: range)
            }
        }
    }

    public func getImage(url: URL, size: CGSize) -> UIImage? {
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

        if let cacheURL = self.getCacheUrl(from: url, prefix: "ThumbnailsBig"), FileManager.default.fileExists(atPath: cacheURL.path) {
            thumbImage = UIImage(contentsOfFile: cacheURL.path)
        } else if
            let resizedImage = self.resize(image: image, size: size) {
            thumbImage = resizedImage
            self.savePreviewImage(url: url, image: resizedImage, prefix: "ThumbnailsBig")
        }

        return thumbImage
    }

    private func getImageSize(imageSize: CGSize) -> CGSize? {
        let controller = UIApplication.getVC()
        let maxWidth = controller.view.frame.width - 100

        guard imageSize.width > maxWidth else {
            return imageSize
        }

        let scale = maxWidth / imageSize.width
        let newHeight = imageSize.height * scale

        return CGSize(width: maxWidth, height: newHeight)
    }

    private func resize(image: UIImage, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

    public func getCacheUrl(from url: URL, prefix: String = "Preview") -> URL? {
        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        temporary.appendPathComponent(prefix)

        if let filePath = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {

            return temporary.appendingPathComponent(filePath)
        }

        return nil
    }

    public func savePreviewImage(url: URL, image: UIImage, prefix: String = "Preview") {
        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        temporary.appendPathComponent(prefix)

        if !FileManager.default.fileExists(atPath: temporary.path) {
            try? FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true, attributes: nil)
        }

        if let url = self.getCacheUrl(from: url, prefix: prefix) {
            if let data = image.jpegData(compressionQuality: 1) {
                try? data.write(to: url)
            }
        }
    }
}
