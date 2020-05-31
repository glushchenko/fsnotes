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
    public func load(lazy: Bool = true) -> NSTextAttachment? {
        let imageSize = getSize(url: self.url)
        guard let size = getImageSize(imageSize: imageSize) else { return nil }

        let attachment = NSTextAttachment()
        attachment.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        if lazy {
            attachment.image = UIImage.emptyImage(with: size)
        } else {
            attachment.image = NoteAttachment.getImage(url: self.url, size: size)
        }

        return attachment
    }

    private func getEditorView() -> EditTextView? {
        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let nav = pc.containerController.viewControllers[1] as? UINavigationController,
            let evc = nav.viewControllers.first as? EditorViewController else { return nil }

        return evc.editArea
    }

    private func getImageSize(imageSize: CGSize) -> CGSize? {
        let controller = UIApplication.getVC()
        let maxWidth = controller.view.frame.width - 15

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

        if let cacheURL = self.getCacheUrl(from: url, prefix: "ThumbnailsBig"), FileManager.default.fileExists(atPath: cacheURL.path) {
            thumbImage = UIImage(contentsOfFile: cacheURL.path)
        } else if
            let resizedImage = self.resize(image: image, size: size) {
            thumbImage = resizedImage
            self.savePreviewImage(url: url, image: resizedImage, prefix: "ThumbnailsBig")
        }

        return thumbImage
    }
}
