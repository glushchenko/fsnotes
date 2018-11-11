//
//  NoteCellView+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 11/6/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

#if os(iOS)
import UIKit
typealias ImageView = UIImageView
#else
import Cocoa
typealias ImageView = NSImageView
#endif

extension NoteCellView {
    public func loadImagesPreview() {
        guard let note = self.note else { return }

        let imageURLs = note.getImagePreviewUrl()

        if note.project.firstLineAsTitle, let firstLine = note.firstLineTitle {
            #if os(iOS)
            self.title.text = firstLine
            self.preview.text = note.preview
            #endif
        } else {
            #if os(iOS)
            self.preview.text = note.getPreviewForLabel()
            self.title.text = note.getTitleWithoutLabel()
            #endif
        }

        guard note.content.length != self.contentLength else { return }

        #if os(iOS)
        guard let tableView = self.superview as? NotesTableView else { return }
        #else
        guard let viewController = NSApp.windows.first?.contentViewController as? ViewController,
            let tableView = viewController.notesTableView else { return }
        #endif

        self.contentLength = note.content.length
        self.note?.invalidateCache()

        self.imagePreview.image = nil
        self.imagePreview.isHidden = true
        self.imagePreviewSecond.image = nil
        self.imagePreviewSecond.isHidden = true
        self.imagePreviewThird.image = nil
        self.imagePreviewThird.isHidden = true

        DispatchQueue.global(qos: .userInteractive).async {
            let current = Date().toMillis()
            self.timestamp = current

            if let images = imageURLs {
                var resizedImages: [Image] = []

                for imageUrl in images {
                    if current != self.timestamp {
                        return
                    }

                    guard let image =
                        ImageAttachment.getImageAndCacheData(url: imageUrl, note: note)
                    else { continue }

                    #if os(iOS)
                        let size = CGRect(x: 0, y: 0, width: 70, height: 70)
                        if let resized = image.resize(height: 70)?.croppedInRect(rect: size) {
                            resizedImages.append(resized)
                        }
                    #else
                        let size = CGSize(width: 70, height: 70)
                        if let resized = image.crop(to: size) {
                            resizedImages.append(resized)
                        }
                    #endif
                }

                DispatchQueue.main.async {
                    if current != self.timestamp {
                        return
                    }

                    for resized in resizedImages {
                        if self.imagePreview.image == nil {
                            self.imagePreview.image = resized

                            self.styleImageView(imageView: self.imagePreview)
                        } else if self.imagePreviewSecond.image == nil {
                            self.imagePreviewSecond.image = resized

                            self.styleImageView(imageView: self.imagePreviewSecond)
                        } else if self.imagePreviewThird.image == nil {
                            self.imagePreviewThird.image = resized

                            self.styleImageView(imageView: self.imagePreviewThird)
                        }
                    }
                }
            }
        }

        tableView.beginUpdates()
        tableView.endUpdates()
    }
}
