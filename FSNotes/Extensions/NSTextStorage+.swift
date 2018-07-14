//
//  NSTextStorage+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

#if os(OSX)
    import Cocoa
    
    extension NSTextStorage {
        func updateFont() {
            beginEditing()
            enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
                if let f = value as? NSFont, let familyName = UserDefaultsManagement.noteFont.familyName {
                    let newFontDescriptor = f.fontDescriptor.withFamily(familyName).withSymbolicTraits(f.fontDescriptor.symbolicTraits)
                    
                    if let newFont = NSFont(descriptor: newFontDescriptor, size: CGFloat(UserDefaultsManagement.fontSize)) {
                        removeAttribute(.font, range: range)
                        addAttribute(.font, value: newFont, range: range)
                    }
                }
            }
            endEditing()
        }
        
        func updateParagraphStyle() {
            beginEditing()
            
            let p = NSMutableParagraphStyle()
            p.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
            
            let attachmentParagraph = NSMutableParagraphStyle()
            attachmentParagraph.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
            attachmentParagraph.alignment = .center
            
            addAttribute(NSAttributedStringKey.paragraphStyle, value: p, range: NSRange(0..<length))
            
            enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
                if let _ = value as? NSTextAttachment {
                    addAttribute(NSAttributedStringKey.paragraphStyle, value: attachmentParagraph, range: range)
                }
            }
            
            endEditing()
        }
    }
#else
    import UIKit
    
    extension NSTextStorage {
        func updateFont() {
            beginEditing()
            enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
                if let f = value as? UIFont {
                    let fontName = UserDefaultsManagement.noteFont.fontName
                    
                    let fd = UIFontDescriptor(name: fontName, size: CGFloat(UserDefaultsManagement.fontSize))
                    fd.withSymbolicTraits(f.fontDescriptor.symbolicTraits)
                    var newFont = UIFont(descriptor: fd, size: CGFloat(UserDefaultsManagement.fontSize))
                    
                    if #available(iOS 11.0, *) {
                        let fontMetrics = UIFontMetrics(forTextStyle: .body)
                        newFont = fontMetrics.scaledFont(for: newFont)
                    }
                    
                    removeAttribute(.font, range: range)
                    addAttribute(.font, value: newFont, range: range)
                }
            }
            endEditing()
        }
    }
#endif


