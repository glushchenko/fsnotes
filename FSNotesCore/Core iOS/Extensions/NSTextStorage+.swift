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
        enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, _) in
            if let font = value as? UIFont {
                var newFont = font.withSize(CGFloat(UserDefaultsManagement.fontSize))

                if #available(iOS 11.0, *), UserDefaultsManagement.dynamicTypeFont {
                    let fontMetrics = UIFontMetrics(forTextStyle: .body)
                    newFont = fontMetrics.scaledFont(for: newFont)
                }

                removeAttribute(.font, range: range)
                addAttribute(.font, value: newFont, range: range)
                fixAttributes(in: range)
            }
        }
        endEditing()
    }

    public func updateParagraphStyle() {
        beginEditing()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        paragraphStyle.alignment = .left

        let attachmentParagraph = NSMutableParagraphStyle()
        attachmentParagraph.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        attachmentParagraph.alignment = .center

        let leftAttachmentParagraph = NSMutableParagraphStyle()
        leftAttachmentParagraph.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        leftAttachmentParagraph.alignment = .left

        mutableString.enumerateSubstrings(in: NSRange(0..<length), options: .byParagraphs) { _, range, _, _ in
            let rangeNewline = range.upperBound == self.length ? range : NSRange(range.location..<range.upperBound + 1)
            self.addAttribute(.paragraphStyle, value: paragraphStyle, range: rangeNewline)
        }

        enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.length)) { (value, range, _) in
            if let attachment = value as? NSTextAttachment,
                self.attribute(.todo, at: range.location,
                effectiveRange: nil) == nil {

                let par = attachment.isFile() ? leftAttachmentParagraph : attachmentParagraph
                addAttribute(.paragraphStyle, value: par, range: range)
            }
        }

        endEditing()
    }
}
