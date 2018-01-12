//
//  ImagesProcessor.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/12/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public class ImagesProcessor {
    public func loadImages(styleApplier: NSMutableAttributedString, range: NSRange? = nil) {
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
                print(path)
                
                if var urlx = URL(string: path) {
                    var isCached = false
                    var localURL: URL?
                    if let generalURL = Storage.generalUrl {
                        localURL = generalURL.appendingPathComponent(urlx.lastPathComponent)
                        if let l = localURL, FileManager.default.fileExists(atPath: l.path) {
                            urlx = l
                            isCached = true
                        }
                    }
                    
                    guard let datax = try? Data(contentsOf: urlx), let imagex = NSImage(dataIgnoringOrientation: datax) else {
                        return
                    }
                    
                    if !isCached, let l = localURL {
                        try? datax.write(to: l, options: .atomic)
                    }
                    
                    let attachment = NSTextAttachment()
                    attachment.image = imagex.imageRotatedByDegreess(degrees: CGFloat(180))
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
