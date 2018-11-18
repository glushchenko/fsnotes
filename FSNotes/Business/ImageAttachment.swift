//
//  ImageAttachment.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/15/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#else
    import UIKit
    import MobileCoreServices
#endif

class ImageAttachment {
    private var title: String
    private var path: String
    private var url: URL
    private var cache: URL?
    private var invalidateRange: NSRange?
    
    init(title: String, path: String, url: URL, cache: URL?, invalidateRange: NSRange? = nil) {
        self.title = title
        self.url = url
        self.path = path
        self.cache = cache
        self.invalidateRange = invalidateRange
    }
    
    public func getAttributedString() -> NSMutableAttributedString?  {
        let pathKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.path")
        let titleKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.title")

        var saveCache: URL?
        let mainURL: URL

        // Get cache url
        if self.url.isRemote(),
            let cacheName = self.url.removingFragment().absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
            let imageCacheUrl = self.cache?.appendingPathComponent(cacheName) {

            if FileManager.default.fileExists(atPath: imageCacheUrl.path) {
                self.url = imageCacheUrl
            } else {
                saveCache = imageCacheUrl
            }
        }

        mainURL = saveCache ?? self.url

        // Save cache and load
        var imageData: Data?
        if let imageCacheUrl = saveCache {
            do {
                imageData = try Data(contentsOf: self.url)

                var isDirectory = ObjCBool(true)
                if let cacheDir = cache, !FileManager.default.fileExists(atPath: cacheDir.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
                    try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: false, attributes: nil)
                }

                try imageData?.write(to: imageCacheUrl, options: .atomic)
            } catch {
                print(error)
            }
        } else {
            imageData = try? Data(contentsOf: mainURL)
        }

        guard let data = imageData, var image = Image(data: data) else { return nil }

        // Make image
        #if os(OSX)

        let fileWrapper = FileWrapper.init(regularFileWithContents: data)
        fileWrapper.preferredFilename = "\(self.title)@::\(mainURL.path)"
        let attachment = NSTextAttachment(fileWrapper: fileWrapper)

        if let rep = image.representations.first {
            let size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            let cell = NSTextAttachmentCell(imageCell: NSImage(size: size))
            attachment.attachmentCell = cell

            DispatchQueue.global().async {
                image = image.resize(to: CGSize(width: rep.pixelsWide, height: rep.pixelsHigh))!

                if let cvc = NSApplication.shared.windows.first?.contentViewController as? ViewController, let view = cvc.editArea, let invalidateRange =  self.invalidateRange {
                    DispatchQueue.main.async {
                        cell.image = image
                        view.layoutManager?.invalidateDisplay(forCharacterRange: invalidateRange)
                    }
                }
            }
        }
        #else
            let attachment = NSTextAttachment()

            if let size = self.getImageSize(image: image) {
                attachment.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)

                DispatchQueue.global().async {
                    if let resizedImage = self.resize(image: image, size: size), let imageData = UIImageJPEGRepresentation(resizedImage, 1) {

                        let fileWrapper = FileWrapper(regularFileWithContents: imageData)
                        fileWrapper.preferredFilename = "\(self.title)@::\(mainURL.path)"
                        attachment.fileType = kUTTypeJPEG as String
                        attachment.fileWrapper = fileWrapper

                        print(attachment)
                        DispatchQueue.main.async {
                            if let view = self.getEditorView(), let invalidateRange =  self.invalidateRange {
                                view.layoutManager.invalidateDisplay(forCharacterRange: invalidateRange)
                            }
                        }
                    }
                }
            }
        #endif

        // Make attributed string
        let attributedString = NSAttributedString(attachment: attachment)
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        
        let ps = NSMutableParagraphStyle()
        ps.alignment = .center
        ps.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        
        let attributes = [
                titleKey: self.title,
                pathKey: self.path,
                .link: String(),
                .attachment: attachment,
                .paragraphStyle: ps
            ] as [NSAttributedStringKey : Any]

        mutableString.addAttributes(attributes, range: NSRange(0..<1))
        return mutableString
    }

    public static func getImageAndCacheData(url: URL, note: Note) -> Image? {
        var data: Data?

        let cacheDirectoryUrl = note.project.url.appendingPathComponent("/.cache/")

        if url.isRemote() || url.pathExtension.lowercased() == "png", let cacheName = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {

            let imageCacheUrl = cacheDirectoryUrl.appendingPathComponent(cacheName)

            if !FileManager.default.fileExists(atPath: imageCacheUrl.path) {
                var isDirectory = ObjCBool(true)
                if !FileManager.default.fileExists(atPath: cacheDirectoryUrl.path, isDirectory: &isDirectory) || isDirectory.boolValue == false {
                    do {
                        try FileManager.default.createDirectory(at: imageCacheUrl.deletingLastPathComponent(), withIntermediateDirectories: false, attributes: nil)
                    } catch {
                        print(error)
                    }
                }

                do {
                    data = try Data(contentsOf: url)
                } catch {
                    print(error)
                }

                #if os(iOS)
                if let imageData = data, let image = UIImage(data: imageData), let jpegImageData = UIImageJPEGRepresentation(image, 1.0) {
                    try? jpegImageData.write(to: imageCacheUrl, options: .atomic)
                    data = jpegImageData
                }
                #endif

            } else {
                data = try? Data(contentsOf: imageCacheUrl)
            }
        } else {
            data = try? Data(contentsOf: url)
        }

        guard let imageData = data else { return nil }

        return Image(data: imageData)
    }

    public static func getCacheUrl(from url: URL) -> URL? {
        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        temporary.appendPathComponent("Preview")

        if let filePath = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {

            return temporary.appendingPathComponent(filePath)
        }

        return nil
    }

    public static func savePreviewImage(url: URL, image: Image) {
        if let url = self.getCacheUrl(from: url) {
            if let data = image.jpgData {
                try? data.write(to: url)
            }
        }
    }

    public static func getPreviewImage(url: URL) -> Image? {
        if let url = self.getCacheUrl(from: url) {
            if let data = try? Data(contentsOf: url) {
                return Image(data: data)
            }
        }

        return nil
    }
    
    #if os(iOS)
    private func getImageSize(image: UIImage) -> CGSize? {
        guard let view = self.getEditorView() else { return nil }

        let maxWidth = view.frame.width - 10

        guard image.size.width > maxWidth else {
            return image.size
        }

        let scale = maxWidth / image.size.width
        let newHeight = image.size.height * scale

        return CGSize(width: maxWidth, height: newHeight)
    }

    private func resize(image: UIImage, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
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
    #endif

}
