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
    public func loadImagesPreview(position: Int? = nil) {
        guard let note = self.note else { return }

        let imageURLs = note.getImagePreviewUrl()
        let imagesFound = imageURLs?.count ?? 0

        guard
            !UserDefaultsManagement.hidePreviewImages &&
            !UserDefaultsManagement.horizontalOrientation else {
            return
        }

        hideUnusedImagesPreview(quantity: imagesFound)

        DispatchQueue.global(qos: .userInteractive).async {
            let current = Date().toMillis()
            self.timestamp = current

            if let images = imageURLs, images.count > 0 {
                let resizedImages = self.getResizedPreviewImages(note: note, images: images, timestamp: current!)

                DispatchQueue.main.async {
                    if current != self.timestamp {
                        return
                    }

                    self.attachImagesPreview(resizedImages: resizedImages)

                    #if os(OSX)
                        self.fixTopConstraint(position: position, note: note)
                    #endif
                }
            }
        }
    }

    private func hideUnusedImagesPreview(quantity: Int) {
        if quantity < 3 {
            self.imagePreviewThird.image = nil
            self.imagePreviewThird.isHidden = true
        }

        if quantity < 2 {
            self.imagePreviewSecond.image = nil
            self.imagePreviewSecond.isHidden = true
        }

        if quantity < 1 {
            self.imagePreview.image = nil
            self.imagePreview.isHidden = true
        }
    }

    private func attachImagesPreview(resizedImages: [Image]) {
        var index = 0
        for resized in resizedImages {
            index += 1

            switch index {
            case 1:
                self.imagePreview.image = resized
                self.styleImageView(imageView: self.imagePreview)
            case 2:
                self.imagePreviewSecond.image = resized
                self.styleImageView(imageView: self.imagePreviewSecond)
            case 3:
                self.imagePreviewThird.image = resized
                self.styleImageView(imageView: self.imagePreviewThird)
            default:
                break
            }
        }
    }

    public func getResizedPreviewImages(note: Note, images: [URL], timestamp: Int64 = 00) -> [Image] {
        var resizedImages: [Image] = []

        for imageUrl in images {
            if timestamp != self.timestamp {
                return []
            }

            if let image = getPreviewImage(imageUrl: imageUrl, note: note) {
                resizedImages.append(image)
            }
        }

        return resizedImages
    }

#if os(OSX)
    private func fixTopConstraint(position: Int?, note: Note) {
        guard let tableView = tableView else { return }

        for constraint in self.constraints {
            if ["firstImageTop", "secondImageTop", "thirdImageTop"].contains(constraint.identifier) {
                let ident = constraint.identifier
                let height = position != nil ? tableView.tableView(tableView, heightOfRow: position!) : self.frame.height

                self.removeConstraint(constraint)
                var con = CGFloat(0)

                if note.getTitle() != nil {
                    con += self.name.frame.height
                }

                let isPreviewExist = note.preview.trim().count > 0
                if isPreviewExist {
                    con += 3 + self.preview.frame.height
                }

                var diff = (height - con - 48) / 2
                diff += con

                var imageLink: NSImageView?
                switch constraint.identifier {
                case "firstImageTop":
                    imageLink = self.imagePreview
                case "secondImageTop":
                    imageLink = self.imagePreviewSecond
                case "thirdImageTop":
                    imageLink = self.imagePreviewThird
                default:
                    imageLink = self.imagePreview
                }

                guard let firstItem = imageLink else { continue }

                let secondItem = isPreviewExist ? self.preview : self
                let secondAttribute: NSLayoutConstraint.Attribute = isPreviewExist ? .bottom : .top
                let constant = isPreviewExist ? 6 : diff
                let constr = NSLayoutConstraint(item: firstItem, attribute: .top, relatedBy: .equal, toItem: secondItem, attribute: secondAttribute, multiplier: 1, constant: constant)

                constr.identifier = ident
                self.addConstraint(constr)
            }
        }
    }
#endif

    public func attachHeaders(note: Note) {
        #if os(OSX)
        if let title = note.getTitle() {
            self.name.stringValue = title
            self.preview.stringValue = note.preview
        } else {
            self.name.stringValue = ""
            self.preview.stringValue = ""
        }

        if let viewController = ViewController.shared(),
            let sidebarItem = viewController.getSidebarItem(),
            let sort = sidebarItem.project?.sortBy,
            sort == .creationDate,
            let date = note.getCreationDateForLabel() {
            self.date.stringValue = date
        } else {
            self.date.stringValue = note.getDateForLabel()
        }

        self.udpateSelectionHighlight()
        #endif
    }
}
