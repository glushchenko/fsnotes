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
        enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, _) in
            if let font = value as? NSFont, let familyName = UserDefaultsManagement.noteFont.familyName {
                let newFontDescriptor = font.fontDescriptor
                    .withFamily(familyName)
                    .withSymbolicTraits(font.fontDescriptor.symbolicTraits)

                if let newFont = NSFont(descriptor: newFontDescriptor, size: CGFloat(UserDefaultsManagement.fontSize)) {
                    removeAttribute(.font, range: range)
                    addAttribute(.font, value: newFont, range: range)
                    fixAttributes(in: range)
                }
            }
        }
        endEditing()
    }

    public func updateParagraphStyle(range: NSRange? = nil) {
        beginEditing()

        var paragraph = NSMutableParagraphStyle()
        let scanRange = range ?? NSRange(0..<length)

        // https://github.com/glushchenko/fsnotes/issues/311
        let tabs = getTabStops()
        let font = UserDefaultsManagement.noteFont!

        mutableString.enumerateSubstrings(in: scanRange, options: .byParagraphs) { value, parRange, _, _ in
            if let value = value,
                value.count > 1,

                value.starts(with: "    ")
                || value.starts(with: "\t")
                || value.starts(with: "* ")
                || value.starts(with: "- ")
                || value.starts(with: "+ ") {

                let prefix = value.getSpacePrefix()
                let checkList = [
                    prefix + "* ",
                    prefix + "- ",
                    prefix + "+ ",
                    "* ",
                    "- ",
                    "+ "
                ]

                var result = String()
                for checkItem in checkList {
                    if value.starts(with: checkItem) {
                        result = checkItem
                        break
                    }
                }

                let width = result.widthOfString(usingFont: font, tabs: tabs)

                paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
                paragraph.alignment = .left
                paragraph.headIndent = width
            } else {
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

    public func sizeAttachmentImages(container: NSTextContainer) {
        enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.length)) { (value, range, _) in
            if let attachment = value as? NSTextAttachment,
                attribute(.todo, at: range.location, effectiveRange: nil) == nil {

                if let imageData = attachment.fileWrapper?.regularFileContents, var image = NSImage(data: imageData) {
                    if let rep = image.representations.first {

                        var maxWidth = UserDefaultsManagement.imagesWidth
                        if maxWidth == Float(1000) {
                            maxWidth = Float(rep.pixelsWide)
                        }

                        let ratio: Float = Float(maxWidth) / Float(rep.pixelsWide)
                        var size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)

                        if ratio < 1 {
                            size = NSSize(width: Int(maxWidth), height: Int(Float(rep.pixelsHigh) * Float(ratio)))
                        }

                        image = image.resize(to: size)!

                        let cell = FSNTextAttachmentCell(textContainer: container, image: NSImage(size: size))
                        cell.image = image
                        attachment.attachmentCell = cell

                        addAttribute(.link, value: String(), range: range)
                    }
                }
            }
        }
    }
}
