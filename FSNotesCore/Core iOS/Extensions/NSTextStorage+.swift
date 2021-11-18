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

    public func updateParagraphStyle(range: NSRange? = nil) {
        var paragraph = NSMutableParagraphStyle()
        let scanRange = range ?? NSRange(0..<length)

        if scanRange.length == 0 {
            return
        }

        beginEditing()

        // https://github.com/glushchenko/fsnotes/issues/311
        let tabs = getTabStops()
        let font = UserDefaultsManagement.noteFont!

        mutableString.enumerateSubstrings(in: scanRange, options: .byParagraphs) { value, parRange, _, _ in
            var parRange = parRange

            if let value = value,
                value.count > 1,

                value.starts(with: "    ")
                || value.starts(with: "\t")
                || value.starts(with: "* ")
                || value.starts(with: "- ")
                || value.starts(with: "+ ")
                || value.starts(with: "> ")
                || self.getNumberListPrefix(paragraph: value) != nil {

                let prefix = value.getSpacePrefix()
                let checkList = [
                    prefix + "* ",
                    prefix + "- ",
                    prefix + "+ ",
                    prefix + "> ",
                    "* ",
                    "- ",
                    "+ ",
                    "> "
                ]

                var result = String()
                for checkItem in checkList {
                    if value.starts(with: checkItem) {
                        result = checkItem
                        break
                    }
                }

                if let prefix = self.getNumberListPrefix(paragraph: value) {
                    result = prefix
                }

                let width = result.widthOfString(usingFont: font, tabs: tabs)

                paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
                paragraph.alignment = .left
                paragraph.headIndent = width
            } else {

                // Fixes new line size (proper line spacing)
                if parRange.length == 0 && parRange.location > 0 {
                    parRange = NSRange(location: parRange.location, length: 1)
                }

                paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
                paragraph.alignment = .left
            }

            paragraph.tabStops = tabs

            self.addAttribute(.paragraphStyle, value: paragraph, range: parRange)
        }

        let spaceWidth = " ".widthOfString(usingFont: font, tabs: tabs)

        // Todo head indents
        enumerateAttribute(.paragraphStyle, in: scanRange, options: .init()) { value, range, _ in
            if attributedSubstring(from: range).attribute(.todo, at: 0, effectiveRange: nil) != nil,
                let parStyle = value as? NSMutableParagraphStyle {

                parStyle.headIndent = font.pointSize + font.pointSize / 2 + spaceWidth
                self.addAttribute(.paragraphStyle, value: parStyle, range: range)
            }
        }

        endEditing()
    }

    public func getTabStops() -> [NSTextTab] {
        var tabs = [NSTextTab]()
        let tabInterval = 40

        for index in 1...25 {
            let tab = NSTextTab(textAlignment: .left, location: CGFloat(tabInterval * index), options: [:])
            tabs.append(tab)
        }

        return tabs
    }

    public func getNumberListPrefix(paragraph: String) -> String? {
        var result = String()
        var numberFound = false
        var dotFound = false

        for char in paragraph {
            if char.isWhitespace {
                result.append(char)
                if dotFound && numberFound {
                    return result
                }
                continue
            } else if char.isNumber {
                numberFound = true
                result.append(char)
                continue
            } else if char == "." {
                if !numberFound {
                    return nil
                }
                dotFound = true
                result.append(char)
                continue
            }

            if !numberFound || !dotFound {
                return nil
            }
        }

        return nil
    }
}
