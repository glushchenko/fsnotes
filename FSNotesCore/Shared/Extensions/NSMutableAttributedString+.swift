//
//  NSMutableAttributedString+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/21/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#else
import Cocoa
#endif

extension NSMutableAttributedString {
    public func unloadImagesAndFiles() -> NSMutableAttributedString {
        let result = NSMutableAttributedString(attributedString: self)
        var offset = 0

        let fullRange = NSRange(location: 0, length: length)
        let pathKey = NSAttributedString.Key("co.fluder.fsnotes.image.path")
        let titleKey = NSAttributedString.Key("co.fluder.fsnotes.image.title")

        enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard
                value as? NSTextAttachment != nil,
                self.attribute(.todo, at: range.location, effectiveRange: nil) == nil
            else {
                return
            }

            guard
                let filePath = self.attribute(pathKey, at: range.location, effectiveRange: nil) as? String,
                !filePath.isEmpty,
                let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            else {
                return
            }

            let title = (self.attribute(titleKey, at: range.location, effectiveRange: nil) as? String) ?? ""
            let replacement = "![\(title)](\(encodedPath))"

            let adjustedRange = NSRange(location: range.location + offset, length: range.length)

            result.removeAttribute(.attachment, range: adjustedRange)
            result.replaceCharacters(in: adjustedRange, with: replacement)

            offset += replacement.count - range.length
        }

        return result
    }

    public func loadImagesAndFiles(note: Note) {
        let paragraphRange = NSRange(0..<length)
        var offset = 0

        var images = [URL]()
        var attachemnts = [URL]()

        FSParser.imageInlineRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard var range = result?.range else { return }

            range = NSRange(location: range.location - offset, length: range.length)
            let mdLink = self.attributedSubstring(from: range).string

            var path = String()
            var title = String()

            if let titleRange = result?.range(at: 2) {
                title = self.mutableString.substring(with: NSRange(location: titleRange.location - offset, length: titleRange.length))
            }

            if let linkRange = result?.range(at: 3) {
                path = self.mutableString.substring(with: NSRange(location: linkRange.location - offset, length: linkRange.length))
            }

            guard let cleanPath = path.removingPercentEncoding,
                  let imageURL = note.getImageUrl(imageName: cleanPath)
            else { return }

            if imageURL.isRemote() {
                //
            } else if FileManager.default.fileExists(atPath: imageURL.path), imageURL.isImage || imageURL.isVideo {
                images.append(imageURL)
            } else {
                attachemnts.append(imageURL)
            }

            let imageAttachment = NoteAttachment(title: title, path: cleanPath, url: imageURL, note: note)

            if let attributedStringWithImage = imageAttachment.getAttributedString() {
                offset += mdLink.count - 1
                self.replaceCharacters(in: range, with: attributedStringWithImage)
            }
        }

        note.imageUrl = images
        note.attachments = attachemnts
    }

    public func unloadTasks() -> NSMutableAttributedString {
        let result = NSMutableAttributedString(attributedString: self)
        var offset = 0
        let fullRange = NSRange(location: 0, length: length)

        enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard
                value != nil,
                range.length == 1,
                let todoValue = self.attribute(.todo, at: range.location, effectiveRange: nil) as? Int
            else {
                return
            }

            let gfm = todoValue == 1 ? "- [x]" : "- [ ]"
            let adjustedRange = NSRange(location: range.location + offset, length: range.length)

            result.replaceCharacters(in: adjustedRange, with: gfm)
            offset += gfm.count - range.length
        }

        return result
    }

    public func loadTasks() {
        while mutableString.contains("- [ ] ") {
            let range = mutableString.range(of: "- [ ] ")
            if length >= range.upperBound, let unChecked = AttributedBox.getUnChecked() {
                replaceCharacters(in: range, with: unChecked)
            }
        }

        while mutableString.contains("- [x] ") {
            let range = mutableString.range(of: "- [x] ")
            let parRange = mutableString.paragraphRange(for: range)

            if length >= range.upperBound, let checked = AttributedBox.getChecked() {
                #if os(macOS)
                let color = UserDataService.instance.isDark ? NSColor.white : NSColor.black
                addAttribute(.strikethroughColor, value: color, range: parRange)
                addAttribute(.strikethroughStyle, value: 1, range: parRange)
                #else
                addAttribute(.strikethroughColor, value: UIColor.blackWhite, range: parRange)
                #endif

                replaceCharacters(in: range, with: checked)
            }
        }
    }

    public func unloadAttachments() -> NSMutableAttributedString {
        return
            unloadTasks()
            .unloadImagesAndFiles()
    }

    public func loadAttachments(_ note: Note) -> NSMutableAttributedString {
        loadImagesAndFiles(note: note)
        loadTasks()
        return self
    }

    public func replaceTag(name: String, with replaceString: String) {
        var scanRange = NSRange(location: 0, length: mutableString.length)
        while true {
            let searchRange = mutableString.range(of: name, options: .caseInsensitive, range: scanRange)
            if searchRange.upperBound > mutableString.length {
                break
            }

            var location = searchRange.location
            var prepend = 0

            if searchRange.location > 0 {
                prepend = 1
                location -= 1
            }

            var length = searchRange.length + prepend
            var append = 0

            if searchRange.location + searchRange.length < mutableString.length {
                append = 1
                length += 1
            }

            let correctedRange = NSRange(location: location, length: length)
            let result = mutableString.substring(with: correctedRange)

            var replaceRange = searchRange

            // drop string
            if replaceString.count == 0 {
                // space OR new line OR start position
                if [" ", "\t", "\n"].contains(result.first) || prepend == 0 {
                    if replaceString.count == 0 {
                        if result.last == "/" {
                            let scanLength = mutableString.length - searchRange.upperBound
                            scanRange = NSRange(location: searchRange.upperBound, length: scanLength)

                            continue
                        }

                        if [" ", "\n"].contains(result.last) {
                            replaceRange = NSRange(location: searchRange.location, length: searchRange.length + 1)
                        }
                    }
                }

                // just replace
                mutableString.replaceCharacters(in: replaceRange, with: replaceString)
            } else {

                // replace only if no tag chars
                if ["/", " ", "\t", "\n"].contains(result.last) || append == 0 {
                    mutableString.replaceCharacters(in: replaceRange, with: replaceString)
                }
            }

            let scanLength = mutableString.length - (searchRange.location + append + replaceString.count)
            if  scanLength <= 0 {
                break
            }

            scanRange = NSRange(location: searchRange.location + replaceString.count + append, length: scanLength)
        }
    }

    func safeAddAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {
        guard range.location != NSNotFound,
              range.location < length else { return }

        let safeLength = min(range.length, length - range.location)
        let safeRange = NSRange(location: range.location, length: safeLength)
        addAttribute(name, value: value, range: safeRange)
    }
}
