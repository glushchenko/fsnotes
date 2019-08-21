//
//  ImageAttachment+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/19/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

extension ImageAttachment {
    public func load() -> NSTextAttachment? {
        let attachment = NSTextAttachment()
        
        let operation = BlockOperation()
        operation.addExecutionBlock {
            guard self.note == EditTextView.note else { return }
            usleep(useconds_t(80000))
            guard self.note == EditTextView.note else { return }

            let imageSize = self.getSize(url: self.url)
            let size = self.getSize(width: imageSize.width, height: imageSize.height)

            if self.note != EditTextView.note { return }

            if let imageData = try? Data(contentsOf: self.url) {
                self.cache(data: imageData)

                let image = Image(data: imageData)
                let fileWrapper = FileWrapper.init(regularFileWithContents: imageData)
                fileWrapper.preferredFilename = "\(self.title)@::\(self.url.path)"

                let resizedImage = image?.resized(to: size)?.roundCorners(withRadius: 3)
                if self.note != EditTextView.note { return }

                DispatchQueue.main.async {
                    let cell = NSTextAttachmentCell(imageCell: resizedImage)
                    attachment.fileWrapper = fileWrapper
                    //attachment.fileType = kUTTypeJPEG as String
                    attachment.attachmentCell = cell

                    if let view = self.getEditorView(), let invalidateRange =  self.invalidateRange, self.note == EditTextView.note {
                        view.layoutManager?.invalidateLayout(forCharacterRange: invalidateRange, actualCharacterRange: nil)
                        view.layoutManager?.invalidateDisplay(forCharacterRange: invalidateRange)
                    }
                }
            }
        }

        EditTextView.imagesLoaderQueue.addOperation(operation)

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

            } else {
                data = try? Data(contentsOf: imageCacheUrl)
            }
        } else {
            data = try? Data(contentsOf: url)
        }

        guard let imageData = data else { return nil }

        return Image(data: imageData)
    }
}
