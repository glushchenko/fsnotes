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
#else
    typealias Size = CGSize
    typealias Image = UIImage
#endif
    
    var textStorageNSString: NSString
    var styleApplier: NSMutableAttributedString
    var range: NSRange?
    var maxWidth: CGFloat
    var note: Note
    var paragraphRange: NSRange
    
    var offset = 0
    var newLineOffset = 0
    
    init(styleApplier: NSMutableAttributedString, range: NSRange? = nil, maxWidth: CGFloat, note: Note) {
        self.styleApplier = styleApplier
        self.range = range
        self.maxWidth = maxWidth
        self.note = note
        self.textStorageNSString = styleApplier.string as NSString
        
        if let unwrappedRange = range {
            paragraphRange = unwrappedRange
        } else {
            paragraphRange = NSRange(0..<styleApplier.length)
        }
    }
    
    public func load() {
        var offset = 0
        
        NotesTextProcessor.imageInlineRegex.matches(self.styleApplier.string, range: paragraphRange) { (result) -> Void in
            guard var range = result?.range else { return }
            
            range = NSRange(location: range.location - offset, length: range.length)
            let mdLink = self.styleApplier.attributedSubstring(from: range).string
            let title = self.getTitle(link: mdLink)
            offset += mdLink.count - 1
            
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
                    guard let innerRange = innerResult?.range else { return }
                    self.styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                }
                
                NotesTextProcessor.imageClosingSquareRegex.matches(self.styleApplier.string, range: range) { (innerResult) -> Void in
                    guard let innerRange = innerResult?.range else { return }
                    self.styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                }
            }
            
            NotesTextProcessor.parenRegex.matches(self.styleApplier.string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                var url: URL?
                
                let filePath = self.getFilePath(innerRange: innerRange)
                
                if let localNotePath = self.getLocalNotePath(path: filePath, innerRange: innerRange), FileManager.default.fileExists(atPath: localNotePath) {
                    url = URL(fileURLWithPath: localNotePath)
                } else if let fs = URL(string: filePath) {
                    url = fs
                }
                
                guard let imageUrl = url else { return }
                
                let cacheUrl = self.note.project?.url.appendingPathComponent("/.cache/")
                let imageAttachment = ImageAttachment(title: title, path: filePath, url: imageUrl, cache: cacheUrl)
                if let attributedStringWithImage = imageAttachment.getAttributedString() {
                    self.styleApplier.replaceCharacters(in: range, with: attributedStringWithImage)
                }
            }
        }
    }
    
    public func unLoad() {
        note.content = NSMutableAttributedString(attributedString: styleApplier.attributedSubstring(from: NSRange(0..<styleApplier.length)))
        
        var offset = 0
        
        self.styleApplier.enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.styleApplier.length)) { (value, range, stop) in
            
            if value != nil {
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
        var notePath: String
        
        guard let noteStorage = self.note.project else {
            return nil
        }
        
        let storagePath = noteStorage.url.path
        
        if note.type == .TextBundle {
            if let name = path.removingPercentEncoding {
                return "\(note.url.path)/\(name)"
            }
        }
        
        if path.starts(with: "http://") || path.starts(with: "https://"), let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            notePath = storagePath + "/i/" + encodedPath
            return notePath
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
    
    func getFileName(from: URL, to: URL) -> String? {
        var name: String?
        let path = from.absoluteString
        
        if path.starts(with: "http://") || path.starts(with: "https://"), let webName = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            name = webName
        }
        
        if path.starts(with: "file://") {
            var i = 0
            var pathComponent = from.lastPathComponent
            let ext = from.pathExtension
            
            while name == nil {
                let destination = to.appendingPathComponent(pathComponent)
                if FileManager.default.fileExists(atPath: destination.path) {
                    i = i + 1
                    pathComponent = "\(i).\(ext)"
                    continue
                }
                
                name = pathComponent
            }
        }

        return name
    }
    
    func writeImage(data: Data, url: URL) -> String? {
        if self.note.type == .TextBundle {
            let assetsUrl = self.note.url.appendingPathComponent("assets")
            
            if !FileManager.default.fileExists(atPath: assetsUrl.path, isDirectory: nil) {
                try? FileManager.default.createDirectory(at: assetsUrl, withIntermediateDirectories: false, attributes: nil)
            }
            
            let destination = URL(fileURLWithPath: assetsUrl.path)
            guard let fileName = getFileName(from: url, to: destination) else {
                return nil
            }
            
            let to = destination.appendingPathComponent(fileName)
            try? data.write(to: to, options: .atomic)
            
            return fileName
        }
        
        if let project = self.note.project {
            let destination = URL(fileURLWithPath: project.url.path + "/i/")
            _ = makeInitialDirectory(cacheURL: destination)
            
            guard let fileName = getFileName(from: url, to: destination) else {
                return nil
            }
            
            let to = destination.appendingPathComponent(fileName)
            try? data.write(to: to, options: .atomic)
            
            return fileName
        }
        
        return nil
    }
    
    func makeInitialDirectory(cacheURL: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: false, attributes: nil)
            return true
        } catch {
            return false
        }
    }
  
    func getImageAttributedString(image: Image) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        
        let attachment = NSTextAttachment()
        
        #if os(OSX)
            let fileWrapper = FileWrapper.init()
            fileWrapper.icon = image
            attachment.fileWrapper = fileWrapper
        #else
            attachment.image = resizeImage(image: image, maxWidth: maxWidth)
        #endif
        
        let attributedString = NSAttributedString(attachment: attachment)
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        
        mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(0..<1))
        
        return mutableString
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
    
    #if os(OSX)
    func computeInEditorSize(image: Image) -> Size {
        let realSize = image.representations[0]
        var scale: CGFloat = 1
    
        if CGFloat(realSize.pixelsWide) > self.maxWidth {
            scale = (self.maxWidth - 20) / CGFloat(realSize.pixelsWide)
        }
    
        let width = CGFloat(realSize.pixelsWide) * scale
        let height = CGFloat(realSize.pixelsHigh) * scale
    
        return Size(width: width, height: height)
    }
    #endif
    
    #if os(iOS)
    func resizeImage(image: UIImage, maxWidth: CGFloat) -> UIImage? {
        guard image.size.width > maxWidth else {
            return image
        }
        
        let scale = maxWidth / image.size.width
        let newHeight = image.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: maxWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: maxWidth, height: newHeight))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    #endif
}
