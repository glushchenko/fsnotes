//
//  ImageAttachment+.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/19/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import MobileCoreServices

extension ImageAttachment {
    public func load() -> NSTextAttachment? {
        let imageSize = getSize(url: self.url)

        let attachment = NSTextAttachment()
        attachment.image = UIImage.emptyImage(with: imageSize)!

        if let size = getImageSize(imageSize: imageSize) {
            attachment.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)

            let operation = BlockOperation()
            operation.addExecutionBlock {
                if let imageData = try? Data(contentsOf: self.url), let image = Image(data: imageData) {

                    self.cache(data: imageData)

                    if let resizedImage = self.resize(image: image, size: size)?.rounded(radius: 5), let imageData = resizedImage.jpegData(compressionQuality: 1) {

                        attachment.contents = imageData
                        attachment.image = resizedImage

                        DispatchQueue.main.async {
                            if let view = self.getEditorView(), let invalidateRange =  self.invalidateRange, self.note == EditTextView.note {
                                view.layoutManager.invalidateLayout(forCharacterRange: invalidateRange, actualCharacterRange: nil)
                                view.layoutManager.invalidateDisplay(forCharacterRange: invalidateRange)
                            }
                        }
                    }
                }
            }

            EditTextView.imagesLoaderQueue.addOperation(operation)
        }

        return attachment
    }

    private func getEditorView() -> EditTextView? {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
            let evc = viewController.viewControllers[0] as? EditorViewController else {
                return nil
        }

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

    private func resize(image: UIImage, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
