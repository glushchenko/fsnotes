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
#if os(OSX)
    public var highlightColor: NSColor {
        get {
            if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
                return NSColor(named: "highlight")!
            } else {
                return NSColor(red:1.00, green:0.90, blue:0.70, alpha:1.0)
            }
        }
    }
#else
    public var highlightColor: UIColor {
        get {
            return UIColor.highlightColor
        }
    }
#endif

    public func getImageRange(url: URL) -> NSRange? {
        let affectedRange = NSRange(0..<length)
        var foundRange: NSRange?

        enumerateAttribute(.attachment, in: affectedRange) { (value, range, stop) in
            guard let meta = getMeta(at: range.location),
                  url.path == meta.url.path else { return }

            foundRange = range
            stop.pointee = true
        }

        return foundRange
    }

    public func updateParagraphStyle(range: NSRange? = nil) {
        let scanRange = range ?? NSRange(0..<length)
        
        guard scanRange.length != 0 else { return }

        beginEditing()
        let font = UserDefaultsManagement.noteFont
        let tabs = getTabStops()
        addTabStops(range: scanRange, tabs: tabs)
        let spaceWidth = " ".widthOfString(usingFont: font, tabs: tabs)

        let parRange = mutableString.paragraphRange(for: scanRange)

        enumerateAttribute(.attachment, in: parRange, options: .init()) { value, range, _ in
            guard attribute(.todo, at: range.location, effectiveRange: nil) != nil else { return }

            let currentParRange = mutableString.paragraphRange(for: range)

            var attachmentWidth: CGFloat = 0
            if let attachment = value as? NSTextAttachment {
                let attachmentBounds = attachment.bounds
                attachmentWidth = attachmentBounds.width
            }

            let parStyle = NSMutableParagraphStyle()
            parStyle.headIndent = spaceWidth + attachmentWidth
            parStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
            addAttribute(.paragraphStyle, value: parStyle, range: currentParRange)
            removeAttribute(.font, range: currentParRange)
            addAttribute(.font, value: UserDefaultsManagement.noteFont, range: currentParRange)
            fixAttributes(in: currentParRange)
        }
        endEditing()
    }

    /*
     * Implements https://github.com/glushchenko/fsnotes/issues/311
     */
    public func addTabStops(range: NSRange, tabs: [NSTextTab]) {
        let font = UserDefaultsManagement.noteFont
        let lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        let paragraphRange = mutableString.paragraphRange(for: range)

        let markers = ["* ", "- ", "+ ", "> "]

        mutableString.enumerateSubstrings(in: paragraphRange, options: .byParagraphs) { value, parRange, _, _ in
            guard let value = value else { return }

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = lineSpacing
            paragraph.alignment = .left
            paragraph.tabStops = tabs

            if value.count > 1 {
                let prefix = value.getSpacePrefix()
                var matchedPrefix: String?

                if prefix.isEmpty {
                    for marker in markers {
                        if value.hasPrefix(marker) {
                            matchedPrefix = marker
                            break
                        }
                    }
                } else {
                    for marker in markers {
                        let fullMarker = prefix + marker
                        if value.hasPrefix(fullMarker) {
                            matchedPrefix = fullMarker
                            break
                        }
                    }
                }

                if matchedPrefix == nil {
                    matchedPrefix = self.getNumberListPrefix(paragraph: value)
                }

                if let prefix = matchedPrefix {
                    paragraph.headIndent = prefix.widthOfString(usingFont: font, tabs: tabs)
                }
            }

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

    private static let numberListRegex = try! NSRegularExpression(
        pattern: #"^(\s*)(\d+)(\.)(\s+)"#,
        options: []
    )

    public func getNumberListPrefix(paragraph: String) -> String? {
        guard !paragraph.isEmpty else { return nil }

        let nsString = paragraph as NSString
        let range = NSRange(location: 0, length: min(nsString.length, 20))

        if let match = Self.numberListRegex.firstMatch(in: paragraph, options: [], range: range) {
            return nsString.substring(with: match.range)
        }

        return nil
    }

    public func updateCheckboxList() {
        let fullRange = NSRange(location: 0, length: self.length)

        enumerateAttribute(.todo, in: fullRange, options: []) { value, range, stop in
            if let value = value as? Int {
                let attribute = self.attribute(.attachment, at: range.location, longestEffectiveRange: nil, in: fullRange)

                if let attachment = attribute as? NSTextAttachment {
                    let checkboxName = value == 0 ? "checkbox_empty" : "checkbox"

                    attachment.image = AttributedBox.getImage(name: checkboxName)

                    for layoutManager in layoutManagers {
                        layoutManager.invalidateDisplay(forCharacterRange: range)
                    }
                }
            }
        }
    }

    public func highlightKeyword(search: String) {
        guard search.count > 0, UserDefaultsManagement.searchHighlight else { return }

        let searchTerm = NSRegularExpression.escapedPattern(for: search)
        let pattern = "(\(searchTerm))"
        let range = NSRange(location: 0, length: length)

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

            regex.enumerateMatches(
                in: self.string,
                options: [],
                range: range
            ) { textCheckingResult, _, _ in
                guard let subRange = textCheckingResult?.range else { return }
                guard subRange.location < self.length else { return }

                if let currentBackgroundColor = self.attribute(.backgroundColor, at: subRange.location, effectiveRange: nil) {
                    self.addAttribute(.highlight, value: currentBackgroundColor, range: subRange)
                } else {
                    self.addAttribute(.highlight, value: NSNull(), range: subRange)
                }

                self.addAttribute(.backgroundColor, value: self.highlightColor, range: subRange)
            }
        } catch {
            print(error)
        }
    }

    public func removeHighlight() {
        let range = NSRange(location: 0, length: length)

        self.enumerateAttribute(
            .highlight,
            in: range,
            options: []
        ) { value, subRange, _ in
            guard value != nil else { return }

            #if os(macOS)
            if let originalColor = value as? NSColor {
                self.addAttribute(.backgroundColor, value: originalColor, range: subRange)
            } else {
                self.removeAttribute(.backgroundColor, range: subRange)
            }
            #else
            if let originalColor = value as? UIColor {
                self.addAttribute(.backgroundColor, value: originalColor, range: subRange)
            } else {
                self.removeAttribute(.backgroundColor, range: subRange)
            }
            #endif

            self.removeAttribute(.highlight, range: subRange)
        }
    }
}
