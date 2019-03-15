//
//  ImagesProcessor.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/12/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
#if os(OSX)
    import Cocoa
#else
    import UIKit
#endif

public class ImagesProcessor {
#if os(OSX)
    typealias Size = NSSize
    typealias Image = NSImage
    typealias TView = EditTextView
#else
    typealias Size = CGSize
    typealias Image = UIImage
    typealias TView = UITextView
#endif

    var styleApplier: NSMutableAttributedString
    var range: NSRange?
    var note: Note
    var paragraphRange: NSRange
    var textView: TView?
    
    var offset = 0
    var newLineOffset = 0
    
    init(styleApplier: NSMutableAttributedString, range: NSRange? = nil, note: Note, textView: TView? = nil) {
        self.styleApplier = styleApplier
        self.range = range
        self.note = note
        self.textView = textView
        
        if let unwrappedRange = range {
            paragraphRange = unwrappedRange
        } else {
            paragraphRange = NSRange(0..<styleApplier.length)
        }
    }
    
    public func load() {
        var offset = 0

        #if NOT_EXTENSION || os(OSX)

        EditTextView.isBusyProcessing = true
        NotesTextProcessor.imageInlineRegex.matches(self.styleApplier.string, range: paragraphRange) { (result) -> Void in
            guard var range = result?.range else {
                EditTextView.isBusyProcessing = false
                return
            }
            
            range = NSRange(location: range.location - offset, length: range.length)
            let mdLink = self.styleApplier.attributedSubstring(from: range).string
            let title = self.getTitle(link: mdLink)
            
            if var font = UserDefaultsManagement.noteFont {
                #if os(iOS)
                if #available(iOS 11.0, *) {
                    let fontMetrics = UIFontMetrics(forTextStyle: .body)
                    font = fontMetrics.scaledFont(for: font)
                }
                #endif
            
                self.styleApplier.addAttribute(.font, value: font, range: range)
            }
            
            if !UserDefaultsManagement.liveImagesPreview {
                NotesTextProcessor.imageOpeningSquareRegex.matches(self.styleApplier.string, range: range) { (innerResult) -> Void in
                    guard let innerRange = innerResult?.range else {
                        EditTextView.isBusyProcessing = false
                        return
                    }

                    self.styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                }
                
                NotesTextProcessor.imageClosingSquareRegex.matches(self.styleApplier.string, range: range) { (innerResult) -> Void in
                    guard let innerRange = innerResult?.range else {
                        EditTextView.isBusyProcessing = false
                        return
                    }
                    self.styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                }
            }
            
            NotesTextProcessor.parenRegex.matches(self.styleApplier.string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else {
                    EditTextView.isBusyProcessing = false
                    return
                }

                var url: URL?
                
                let filePath = self.getFilePath(innerRange: innerRange)
                
                if let localNotePath = self.getLocalNotePath(path: filePath, innerRange: innerRange), FileManager.default.fileExists(atPath: localNotePath) {
                    url = URL(fileURLWithPath: localNotePath)
                } else if let fs = URL(string: filePath) {
                    url = fs
                }
                
                guard let imageUrl = url else {
                    EditTextView.isBusyProcessing = false
                    return
                }

                let invalidateRange = NSRange(location: range.location, length: 1)
                let cacheUrl = self.note.project.url.appendingPathComponent("/.cache/")

                if EditTextView.note?.url.absoluteString != self.note.url.absoluteString {
                    EditTextView.isBusyProcessing = false
                    return
                }

                let imageAttachment = ImageAttachment(title: title, path: filePath, url: imageUrl, cache: cacheUrl, invalidateRange: invalidateRange, note: self.note)

                if let attributedStringWithImage = imageAttachment.getAttributedString() {
                    offset += mdLink.count - 1
                    self.styleApplier.replaceCharacters(in: range, with: attributedStringWithImage)
                }
            }
        }
        EditTextView.isBusyProcessing = false

        #endif
    }
    
    public func unLoad() {
        guard note.container != .encryptedTextPack else { return }
        
        note.content = NSMutableAttributedString(attributedString: styleApplier.attributedSubstring(from: NSRange(0..<styleApplier.length)))
        
        var offset = 0

        self.styleApplier.enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.styleApplier.length)) { (value, range, stop) in

            if value != nil, self.styleApplier.attribute(.todo, at: range.location, effectiveRange: nil) == nil {
                let newRange = NSRange(location: range.location + offset, length: range.length)
                let filePathKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.path")
                let titleKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.title")
                
                guard
                    let path = self.styleApplier.attribute(filePathKey, at: range.location, effectiveRange: nil) as? String,
                    let title = self.styleApplier.attribute(titleKey, at: range.location, effectiveRange: nil) as? String else { return }
                
                if let pathEncoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    self.note.content.replaceCharacters(in: newRange, with: "![\(title)](\(pathEncoded))")
                    offset += 4 + path.count + title.count
                }
            }
        }
    }
    
    func computeMarkdownTitleLength(mdLink: String) -> Int {
        var mdTitleLength = 0
        if let match = mdLink.range(of: "\\[(.+)\\]", options: .regularExpression) {
            mdTitleLength = mdLink[match].count - 2
        }
        
        return mdTitleLength
    }
    
    private func getTitle(link: String) -> String {
        if let match = link.range(of: "\\[(.+)\\]", options: .regularExpression) {
            let title = link[match]
            return String(title.dropLast().dropFirst())
        }
        
        return ""
    }
    
    func getLocalNotePath(path: String, innerRange: NSRange) -> String? {
        let noteStorage = self.note.project
        var notePath: String
        let storagePath = noteStorage.url.path
        
        if path.starts(with: "/i/") {
            let path = getFilePath(innerRange: innerRange)
            return note.project.url.path + path
        }
        
        if path.starts(with: "http://") || path.starts(with: "https://"), let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            notePath = storagePath + "/i/" + encodedPath
            return notePath
        }
        
        if note.isTextBundle() {
            if let name = path.removingPercentEncoding {
                return "\(note.getURL().path)/\(name)"
            }
        }

        let path = getFilePath(innerRange: innerRange)
        notePath = storagePath + "/" + path
        
        return notePath
    }
    
    func getFilePath(innerRange: NSRange) -> String {
        let link = NSRange(location: innerRange.location + 1 + offset, length: innerRange.length - 2)
        if let path = styleApplier.attributedSubstring(from: link).string.removingPercentEncoding {
            return path
        }

        return ""
    }
    
    public static func getFileName(from: URL? = nil, to: URL, ext: String? = nil) -> String? {
        let path = from?.absoluteString ?? to.absoluteString
        var name: String?

        if path.starts(with: "http://") || path.starts(with: "https://"), let webName = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            name = webName
        }
        
        if path.starts(with: "file://") {
            var ext = ext ?? "jpg"
            var pathComponent = NSUUID().uuidString.lowercased() + "." + ext

            if let from = from {
                pathComponent = from.lastPathComponent
                ext = from.pathExtension
            }

            while name == nil {
                let destination = to.appendingPathComponent(pathComponent)
                let icloud = destination.appendingPathExtension("icloud")
                
                if FileManager.default.fileExists(atPath: destination.path) || FileManager.default.fileExists(atPath: icloud.path) {
                    pathComponent = NSUUID().uuidString.lowercased() + ".\(ext)"
                    continue
                }
                
                name = pathComponent
            }
        }

        return name
    }
    
    public static func writeImage(data: Data, url: URL? = nil, note: Note, ext: String? = nil) -> String? {
        if note.isTextBundle() {
            let assetsUrl = note.getURL().appendingPathComponent("assets")
            
            if !FileManager.default.fileExists(atPath: assetsUrl.path, isDirectory: nil) {
                try? FileManager.default.createDirectory(at: assetsUrl, withIntermediateDirectories: true, attributes: nil)
            }

            let destination = URL(fileURLWithPath: assetsUrl.path)
            guard let fileName = ImagesProcessor.getFileName(from: url, to: destination, ext: ext) else {
                return nil
            }
            
            let to = destination.appendingPathComponent(fileName)
            do {
                try data.write(to: to, options: .atomic)
            } catch {
                print(error)
            }
            
            return fileName
        }
        
        let project = note.project
        let destination = URL(fileURLWithPath: project.url.path + "/i/")

        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false, attributes: nil)
        } catch {
        }

        guard let fileName = ImagesProcessor.getFileName(from: url, to: destination, ext: ext) else {
            return nil
        }

        let to = destination.appendingPathComponent(fileName)
        try? data.write(to: to, options: .atomic)

        return fileName
    }

    func isContainAttachment(innerRange: NSRange, mdTitleLength: Int) -> Bool {
        let j = offset + newLineOffset - mdTitleLength
        
        if innerRange.lowerBound >= 5 + mdTitleLength {
            return self.styleApplier.containsAttachments(in: NSMakeRange(innerRange.lowerBound - 5 + j, 1))
        }
        
        return false
    }
    
    func isContainNewLine(innerRange: NSRange, mdTitleLength: Int) -> Bool {
        let j = offset + newLineOffset - mdTitleLength
        
        if innerRange.lowerBound >= 4 + mdTitleLength {
            return (self.styleApplier.attributedSubstring(from: NSMakeRange(innerRange.lowerBound - 4 + j, 1)).string == "\n")
        }
        
        return false
    }
}
