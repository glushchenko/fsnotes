//
//  NSTextStorage+.swift
//  FSNotesCore macOS
//
//  Created by Oleksandr Glushchenko on 7/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

import Cocoa

extension NSTextStorage {
    public func updateFont() {
        beginEditing()
        enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let font = value as? NSFont, let familyName = UserDefaultsManagement.noteFont.familyName {
                let newFontDescriptor = font.fontDescriptor.withFamily(familyName).withSymbolicTraits(font.fontDescriptor.symbolicTraits)

                if let newFont = NSFont(descriptor: newFontDescriptor, size: CGFloat(UserDefaultsManagement.fontSize)) {
                    removeAttribute(.font, range: range)
                    addAttribute(.font, value: newFont, range: range)
                }
            }
        }
        endEditing()
    }

    public func updateParagraphStyle() {
        beginEditing()
        
        let par = NSMutableParagraphStyle()
        par.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        
        let attachmentParagraph = NSMutableParagraphStyle()
        attachmentParagraph.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        attachmentParagraph.alignment = .center
        
        addAttribute(NSAttributedString.Key.paragraphStyle, value: par, range: NSRange(0..<length))
        
        enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let _ = value as? NSTextAttachment {
                addAttribute(NSAttributedString.Key.paragraphStyle, value: attachmentParagraph, range: range)
            }
        }
        
        endEditing()
    }
}
