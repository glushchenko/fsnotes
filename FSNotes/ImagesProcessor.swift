//
//  ImagesProcessor.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/12/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public class ImagesProcessor {
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
        let string = styleApplier.string
        
        NotesTextProcessor.imageInlineRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            
            let mdLink = self.textStorageNSString.substring(with: range)
            let mdTitleLength = self.computeMarkdownTitleLength(mdLink: mdLink)
            
            self.styleApplier.addAttribute(.font, value: UserDefaultsManagement.noteFont, range: range)
            
            NotesTextProcessor.imageOpeningSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                self.styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
            }
            
            NotesTextProcessor.imageClosingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                self.styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
            }
            
            NotesTextProcessor.parenRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                
                self.styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                
                let filePath = self.getFilePath(innerRange: innerRange)
                
                if var imageURL = URL(string: filePath) {
                    var isCached = false
                    
                    if let localNotePath = self.getLocalNotePath(urlx: imageURL, innerRange: innerRange), FileManager.default.fileExists(atPath: localNotePath) {
                        imageURL = URL(fileURLWithPath: localNotePath)
                        isCached = true
                    }
                    
                    guard let imageData = try? Data(contentsOf: imageURL), let image = NSImage(data: imageData) else {
                        return
                    }

                    if !isCached {
                        self.cache(data: imageData, url: imageURL)
                    }
                    
                    self.replaceAttributedString(innerRange: innerRange, mdTitleLength: mdTitleLength, image: image)
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
    
    func getLocalNotePath(urlx: URL, innerRange: NSRange) -> String? {
        guard let noteStorage = self.note.storage, let storagePath = noteStorage.getPath() else {
            return nil
        }
        
        var notePath: String
        
        if let scheme = urlx.scheme, ["http", "https"].contains(scheme), let encodedPath = urlx.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
            notePath = storagePath + "/i/" + encodedPath
        } else {
            notePath = storagePath + "/" + getFilePath(innerRange: innerRange)
        }
        
        return notePath
    }
    
    func getFilePath(innerRange: NSRange) -> String {
        let link = NSRange(location: innerRange.location + 1, length: innerRange.length - 2)
        let path = textStorageNSString.substring(with: link)
        return path
    }
    
    func cache(data: Data, url: URL) {
        if let noteStorage = self.note.storage, let storagePath = noteStorage.getPath(), let p = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
            
            let cacheURL = URL(fileURLWithPath: storagePath + "/i/")
            let cacheFile = URL(fileURLWithPath: storagePath + "/i/" + p)
            
            do {
                try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: false, attributes: nil)
            } catch {}
            
            try? data.write(to: cacheFile, options: .atomic)
        }
    }
    
    func computeInEditorSize(image: NSImage) -> NSSize {
        let realSize = image.representations[0]
        var scale: CGFloat = 1
        
        if CGFloat(realSize.pixelsWide) > self.maxWidth {
            scale = (self.maxWidth - 20) / CGFloat(realSize.pixelsWide)
        }
        
        let width = CGFloat(realSize.pixelsWide) * scale
        let height = CGFloat(realSize.pixelsHigh) * scale
        
        return NSSize(width: width, height: height)
    }
    
    func getImageAttributedString(image: NSImage) -> NSAttributedString {
        image.size = self.computeInEditorSize(image: image)
        
        let fileWrapper = FileWrapper.init()
        fileWrapper.icon = image
        
        let attachment = NSTextAttachment()
        attachment.fileWrapper = fileWrapper
        
        return NSAttributedString(attachment: attachment)
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
    
    func replaceAttributedString(innerRange: NSRange, mdTitleLength: Int, image: NSImage) {
        let attrStringWithImage = self.getImageAttributedString(image: image)
        
        guard self.styleApplier.length >= innerRange.location + innerRange.length else {
            return
        }
        
        let attachmentExist = self.isContainAttachment(innerRange: innerRange, mdTitleLength: mdTitleLength)
        
        let newLine = self.isContainNewLine(innerRange: innerRange, mdTitleLength: mdTitleLength)
        
        let j = offset + newLineOffset - mdTitleLength
        
        guard !attachmentExist else {
            self.styleApplier.replaceCharacters(in: NSMakeRange(innerRange.lowerBound - 5 + j, 1), with: attrStringWithImage)
            return
        }
        
        if !newLine {
            self.styleApplier.replaceCharacters(in: NSMakeRange(innerRange.lowerBound - 3 + j, 0), with: NSAttributedString(string: "\n"))
            self.styleApplier.replaceCharacters(in: NSMakeRange(innerRange.lowerBound - 3 + j, 0), with: attrStringWithImage)
            
            offset = offset + 2
        } else {
            self.styleApplier.replaceCharacters(in: NSMakeRange(innerRange.lowerBound - 4 + j, 0), with: attrStringWithImage)
            
            offset = offset + 1
        }
    }
}
