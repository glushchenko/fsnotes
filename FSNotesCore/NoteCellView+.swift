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
    public func loadImagesPreview(position: Int? = nil, urls: [URL]? = nil) {
        guard let note = self.note else {
            hideUnusedImagesPreview()
            imageKeys = []
            return
        }

        note.loadPreviewInfo()

        guard
            !UserDefaultsManagement.hidePreviewImages &&
            !UserDefaultsManagement.horizontalOrientation else {
            hideUnusedImagesPreview()
            imageKeys = []
            return
        }

        let imageURLs = urls ?? note.imageUrl
        
        guard let imageURLs = imageURLs, !imageURLs.isEmpty else {
            hideUnusedImagesPreview()
            imageKeys = []
            attachHeaders(note: note)
            fixTopConstraint(position: position, note: note)
            return
        }
        
        let isNotAssigned = imagePreview.image == nil
            && imagePreviewSecond.image == nil
            && imagePreviewThird.image == nil
        
        let isAssigned = imagePreview.image != nil ||
            imagePreviewSecond.image != nil ||
            imagePreviewThird.image != nil

        let needsReload = isImagesChanged(imageURLs: imageURLs)
        
        if !needsReload && !isNotAssigned {
            attachHeaders(note: note)
            fixTopConstraint(position: position, note: note)
            return
        }

        if needsReload || (isNotAssigned && isAssigned) {
            hideUnusedImagesPreview()
            imageKeys = []
        }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            let current = Date().toMillis()
            self.timestamp = current
            var paths = [String]()

            let resizedImages = self.getResizedPreviewImages(note: note, images: imageURLs, timestamp: current!)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if current != self.timestamp {
                    return
                }
                
                guard self.note === note else {
                    return
                }

                for imageUrl in imageURLs {
                    paths.append(imageUrl.path)
                }

                self.imageKeys = paths
                self.attachImagesPreview(resizedImages: resizedImages)
                self.fixTopConstraint(position: position, note: note)
            }
        }
    }

    private func isImagesChanged(imageURLs: [URL]? = nil) -> Bool {
        guard let imageURLs = imageURLs else {
            return !imageKeys.isEmpty
        }

        if imageURLs.count != imageKeys.count {
            return true
        }
        
        let newPaths = Set(imageURLs.map { $0.path })
        let currentPaths = Set(imageKeys)
        
        return newPaths != currentPaths
    }

    private func hideUnusedImagesPreview() {
        self.imagePreviewThird.image = nil
        self.imagePreviewThird.isHidden = true

        self.imagePreviewSecond.image = nil
        self.imagePreviewSecond.isHidden = true

        self.imagePreview.image = nil
        self.imagePreview.isHidden = true
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
        
        if resizedImages.count < 3 {
            self.imagePreviewThird.image = nil
            self.imagePreviewThird.isHidden = true
        }
        if resizedImages.count < 2 {
            self.imagePreviewSecond.image = nil
            self.imagePreviewSecond.isHidden = true
        }
        if resizedImages.count < 1 {
            self.imagePreview.image = nil
            self.imagePreview.isHidden = true
        }
        
    #if os(macOS)
        self.needsDisplay = true
        self.needsLayout = true
                
        self.imagePreview.needsDisplay = true
        self.imagePreviewSecond.needsDisplay = true
        self.imagePreviewThird.needsDisplay = true
        
        self.layoutSubtreeIfNeeded()
        self.superview?.needsLayout = true
        self.superview?.layoutSubtreeIfNeeded()
    #endif
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
}
