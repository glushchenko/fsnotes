//
//  ImagesProcessor.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/12/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public class ImagesProcessor {
    public func loadImages(styleApplier: NSMutableAttributedString, range: NSRange? = nil, maxWidth: CGFloat, note: Note) {

        var paragraphRange: NSRange
        if let unwrappedRange = range {
            paragraphRange = unwrappedRange
        } else {
            paragraphRange = NSRange(0..<styleApplier.length)
        }

        let string = styleApplier.string
        var offset = 0
        var newLineOffset = 0
        let textStorageNSString = styleApplier.string as NSString
        
        // We detect and process inline images
        NotesTextProcessor.imageInlineRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            let mdLink = textStorageNSString.substring(with: range)
            
            var mdTitleLength = 0
            if let match = mdLink.range(of: "\\[(.+)\\]", options: .regularExpression) {
                mdTitleLength = mdLink[match].count - 2
            }
            
            styleApplier.addAttribute(.font, value: UserDefaultsManagement.noteFont, range: range)
            
            NotesTextProcessor.imageOpeningSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
            }
            
            NotesTextProcessor.imageClosingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
            }
            
            NotesTextProcessor.parenRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                
                let link = NSRange(location: innerRange.location + 1, length: innerRange.length - 2)
                let path = textStorageNSString.substring(with: link)

                if var urlx = URL(string: path) {
                    var isCached = false
                    
                    if let noteStorage = note.storage, let storagePath = noteStorage.getPath() {
                        var notePath: String
                        if let scheme = urlx.scheme, ["http", "https"].contains(scheme), let encodedPath = urlx.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                            
                            notePath = storagePath + "/i/" + encodedPath
                        } else {
                            notePath = storagePath + "/" + path
                        }
                        
                        if FileManager.default.fileExists(atPath: notePath) {
                            urlx = URL(fileURLWithPath: notePath)
                            isCached = true
                        }
                    }
                    
                    guard let datax = try? Data(contentsOf: urlx), let imagex = NSImage(data: datax) else {
                        return
                    }
                    
                    if !isCached, let noteStorage = note.storage, let storagePath = noteStorage.getPath(), let p = urlx.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                        
                        let cacheURL = URL(fileURLWithPath: storagePath + "/i/")
                        let cacheFile = URL(fileURLWithPath: storagePath + "/i/" + p)
                        
                        do {
                            try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: false, attributes: nil)
                        } catch {}
                        
                        try? datax.write(to: cacheFile, options: .atomic)
                    }
                    
                    let realSize = imagex.representations[0]
                    var scale: CGFloat = 1
                    
                    if CGFloat(realSize.pixelsWide) > maxWidth {
                        scale = (maxWidth - 20) / CGFloat(realSize.pixelsWide)
                    }
                    
                    let width = CGFloat(realSize.pixelsWide) * scale
                    let height = CGFloat(realSize.pixelsHigh) * scale
                    imagex.size = NSSize(width: width, height: height)
                    
                    let attachment = NSTextAttachment()
                    let fileWrapper = FileWrapper.init()
                    fileWrapper.icon = imagex
                    attachment.fileWrapper = fileWrapper
                    
                    let attrStringWithImage = NSAttributedString(attachment: attachment)
                    guard styleApplier.length >= innerRange.location + innerRange.length else {
                        return
                    }
                    
                    var newLine = false
                    var attachmentExist = false
                    
                    let j = offset + newLineOffset - mdTitleLength
                    
                    if innerRange.lowerBound >= 4 + mdTitleLength {
                        newLine = (styleApplier.attributedSubstring(from: NSMakeRange(innerRange.lowerBound - 4 + j, 1)).string == "\n")
                    }
                    
                    if innerRange.lowerBound >= 5 + mdTitleLength {
                        attachmentExist = styleApplier.containsAttachments(in: NSMakeRange(innerRange.lowerBound - 5 + j, 1))
                    }
                    
                    guard !attachmentExist else {
                        styleApplier.replaceCharacters(in: NSMakeRange(innerRange.lowerBound - 5 + j, 1), with: attrStringWithImage)
                        return
                    }
                    
                    if !newLine {
                        styleApplier.replaceCharacters(in: NSMakeRange(innerRange.lowerBound - 3 + j, 0), with: NSAttributedString(string: "\n"))
                        styleApplier.replaceCharacters(in: NSMakeRange(innerRange.lowerBound - 3 + j, 0), with: attrStringWithImage)
                        
                        newLineOffset = newLineOffset + 1
                    } else {
                        styleApplier.replaceCharacters(in: NSMakeRange(innerRange.lowerBound - 4 + j, 0), with: attrStringWithImage)
                    }
                    
                    offset = offset + 1
                }
            }
        }
    }
}
