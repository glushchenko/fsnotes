//
//  NSTextStorage+.swift
//  FSNotesCore iOS
//
//  Created by Oleksandr Glushchenko on 7/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension NSTextStorage {
    public func updateFont() {
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
    
    public func updateParagraphStyle() {
        beginEditing()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        
        let attachmentParagraph = NSMutableParagraphStyle()
        attachmentParagraph.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        attachmentParagraph.alignment = .center
        
        addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: NSRange(0..<length))
        
        enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let _ = value as? NSTextAttachment {
                addAttribute(NSAttributedString.Key.paragraphStyle, value: attachmentParagraph, range: range)
            }
        }
        
        endEditing()
    }
}
