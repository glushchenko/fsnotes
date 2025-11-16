//
//  NSMutableAttributedString+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/21/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

#if os(OSX)
import AppKit
#else
import UIKit
#endif

extension NSMutableAttributedString {

    convenience init(url: URL, title: String = "", path: String) {
        let attachment = NSTextAttachment(url: url, path: path, title: title)
        let attributedAttachment = NSMutableAttributedString(attachment: attachment)

        let range = NSRange(location: 0, length: 1)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = url.isImage ? .center : .left

        attributedAttachment.addAttributes([.paragraphStyle: paragraphStyle], range: range)

    #if os(iOS)
        // Only one way to store metadata in iOS
        attributedAttachment.addAttribute(.attachmentUrl, value: url, range: range)
        attributedAttachment.addAttribute(.attachmentPath, value: path, range: range)
        attributedAttachment.addAttribute(.attachmentTitle, value: title, range: range)
    #endif

        self.init(attributedString: attributedAttachment)
    }

    public func unloadImagesAndFiles() -> NSMutableAttributedString {
        let result = NSMutableAttributedString(attributedString: self)
        let fullRange = NSRange(location: 0, length: result.length)

        enumerateAttribute(.attachment, in: fullRange, options: .reverse) { value, range, _ in
            guard let meta = getMeta(at: range.location) else { return }

            let path = meta.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? meta.path
            let title = meta.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? meta.title

            let replacement = "![\(title)](\(path))"
            result.removeAttribute(.attachment, range: range)
            result.replaceCharacters(in: range, with: replacement)
        }

        return result
    }

    public func loadImagesAndFiles(note: Note) {
        let fullRange = NSRange(location: 0, length: length)
        var offset = 0

        var images: [URL] = []
        var attachments: [URL] = []

        FSParser.imageInlineRegex.matches(string, range: fullRange) { result in
            guard let result = result else { return }

            var range = result.range
            range.location -= offset

            let title = result.optionalRange(at: 2).flatMap {
                self.mutableString.substring(with: NSRange(location: $0.location - offset, length: $0.length))
            } ?? ""

            let path = result.optionalRange(at: 3).flatMap {
                self.mutableString.substring(with: NSRange(location: $0.location - offset, length: $0.length))
            } ?? ""

            guard
                let cleanPath = path.removingPercentEncoding,
                let fileURL = note.getAttachmentFileUrl(name: cleanPath)
            else { return }

            if fileURL.isRemote() {
                return

            } else if FileManager.default.fileExists(atPath: fileURL.path),
                      fileURL.isImage || fileURL.isVideo {
                images.append(fileURL)
            } else {
                attachments.append(fileURL)
            }

            let attributedAttachment = NSMutableAttributedString(url: fileURL, title: title, path: cleanPath)
            self.replaceCharacters(in: range, with: attributedAttachment)
            offset += range.length - 1
        }

        note.imageUrl = images
        note.attachments = attachments
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
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = "(?<=^|\\s)\(escapedName)(?=$|\\s|/)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return
        }

        let fullRange = NSRange(location: 0, length: mutableString.length)
        let matches = regex.matches(in: mutableString as String, options: [], range: fullRange)

        for match in matches.reversed() {
            if replaceString.isEmpty {
                mutableString.replaceCharacters(in: match.range, with: "")
            } else {
                mutableString.replaceCharacters(in: match.range, with: replaceString)
            }
        }
    }

    public func getImagesAndFiles() -> [Attachment] {
        var res = [Attachment]()

        let fullRange = NSRange(location: 0, length: length)
        enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard let meta = getMeta(at: range.location) else { return }
            res.append(meta)
        }

        return res
    }

    public static func buildFromRtfd(data: Data) -> NSMutableAttributedString? {
        let options = [
            NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtfd
        ] as [NSAttributedString.DocumentReadingOptionKey : Any]

        if let attributed = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil) {
            attributed.loadTasks()

            return attributed
        }

        return nil
    }

    public func getMeta(at location: Int) -> Attachment? {
        guard location >= 0 && location < self.length else { return nil }

    #if os(iOS)
        guard let url = attribute(.attachmentUrl, at: location, effectiveRange: nil) as? URL,
              let path = attribute(.attachmentPath, at: location, effectiveRange: nil) as? String else { return nil }

        let title = attribute(.attachmentTitle, at: location, effectiveRange: nil) as? String ?? String()

        var meta = Attachment(url: url, title: title, path: path)
        meta.preferredName = url.lastPathComponent

        return meta
    #else
        guard let attachment = attribute(.attachment, at: location, effectiveRange: nil) else { return nil }

        return attachment.getMeta()
    #endif
    }

    public func getData(at location: Int) -> Data? {
        guard location >= 0 && location < self.length else { return nil }
        
        let range = NSRange(location: location, length: 1)

        #if os(iOS)
        if attribute(.attachmentSave, at: location, effectiveRange: nil) != nil {
            guard let url = attribute(.attachmentUrl, at: location, effectiveRange: nil) as? URL else { return nil }
            removeAttribute(.attachmentSave, range: range)
            return try? Data(contentsOf: url)
        }
        #else
            guard let attachment = attribute(.attachment, at: location, effectiveRange: nil) else { return nil }
            return attachment.getMeta()?.data
        #endif

        return nil
    }
}
