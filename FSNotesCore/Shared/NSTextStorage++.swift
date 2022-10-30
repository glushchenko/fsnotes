//
//  CustomTextStorage.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/12/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

#if os(OSX)
import AppKit
#else
import UIKit
#endif

extension NSTextStorage {
    public func getImageRange(url: URL) -> NSRange? {
        let affectedRange = NSRange(0..<length)
        var foundRange: NSRange?

        enumerateAttribute(.attachment, in: affectedRange) { (value, range, stop) in
            if value as? NSTextAttachment != nil, attribute(.todo, at: range.location, effectiveRange: nil) == nil {

                let pathKey = NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.url")
                if let result = attribute(pathKey, at: range.location, effectiveRange: nil) as? URL, url.path == result.path {

                    foundRange = range
                    stop.pointee = true
                }
            }
        }

        return foundRange
    }

    public func updateParagraphStyle(range: NSRange? = nil) {
        let scanRange = range ?? NSRange(0..<length)

        if scanRange.length == 0 {
            return
        }

        beginEditing()

        let font = UserDefaultsManagement.noteFont
        let tabs = getTabStops()

        addTabStops(range: scanRange, tabs: tabs)

        let spaceWidth = " ".widthOfString(usingFont: font, tabs: tabs)

        // Todo head indents
        enumerateAttribute(.attachment, in: scanRange, options: .init()) { value, range, _ in
            if attribute(.todo, at: range.location, effectiveRange: nil) != nil {
                let parRange = mutableString.paragraphRange(for: NSRange(location: range.location, length: 0))
                let parStyle = NSMutableParagraphStyle()
                parStyle.headIndent = font.pointSize + font.pointSize / 2 + spaceWidth
                parStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
                addAttribute(.paragraphStyle, value: parStyle, range: parRange)
            }
        }

        endEditing()
    }

    /*
     * Implements https://github.com/glushchenko/fsnotes/issues/311
     */
    public func addTabStops(range: NSRange, tabs: [NSTextTab]) {
        var paragraph = NSMutableParagraphStyle()
        let font = UserDefaultsManagement.noteFont

        mutableString.enumerateSubstrings(in: range, options: .byParagraphs) { value, parRange, _, _ in
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
