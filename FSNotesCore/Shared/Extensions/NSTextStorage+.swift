//
//  NSTextStorage+.swift
//  FSNotes
//
//  Created by Александр on 24.10.2021.
//  Copyright © 2021 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

extension NSTextStorage {
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
