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

extension NSTextStorage: NSTextStorageDelegate {

#if os(iOS)
    public func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorage.EditActions,
        range editedRange: NSRange,
        changeInLength delta: Int) {

        guard editedMask != .editedAttributes else { return }
        process(textStorage: textStorage, range: editedRange, changeInLength: delta)
    }
#else
    public func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int) {

        guard editedMask != .editedAttributes else { return }
        process(textStorage: textStorage, range: editedRange, changeInLength: delta)
    }
#endif

    private func process(textStorage: NSTextStorage, range editedRange: NSRange, changeInLength delta: Int) {
        guard let note = EditTextView.note, note.isMarkdown() else { return }
        guard delta != 0 || EditTextView.shouldForceRescan else { return }

        if note.content.string.md5 != note.cacheHash {
            if editedRange.length > 300000 {
                NotesTextProcessor.minimalHighlight(attributedString: textStorage, note: note)
                return
            }

            if shouldScanСompletely(textStorage: textStorage, editedRange: editedRange) {
                rescanAll(textStorage: textStorage)
            } else {
                rescanPartial(textStorage: textStorage, delta: delta, editedRange: editedRange)
            }
        } else {
            updateParagraphStyle()
        }

        loadImages(textStorage: textStorage, checkRange: editedRange)

        EditTextView.shouldForceRescan = false
        EditTextView.lastRemoved = nil
    }

    private func shouldScanСompletely(textStorage: NSTextStorage, editedRange: NSRange) -> Bool {
        if editedRange.length == textStorage.length {
            return true
        }

        let string = textStorage.mutableString.substring(with: editedRange)

        return
            string == "`"
            || string == "`\n"
            || EditTextView.lastRemoved == "`"
            || (
                EditTextView.shouldForceRescan
                && string.contains("```")
            )
    }

    private func rescanAll(textStorage: NSTextStorage) {
        guard let note = EditTextView.note else { return }

        let range = NSRange(0..<textStorage.length)
        removeAttribute(.backgroundColor, range: range)

        NotesTextProcessor.highlightMarkdown(attributedString: textStorage, note: note)
        NotesTextProcessor.highlightFencedAndIndentCodeBlocks(attributedString: textStorage)

        updateParagraphStyle()
    }

    private func rescanPartial(textStorage: NSTextStorage, delta: Int, editedRange: NSRange) {
        guard delta == 1 || delta == -1 else {
            highlightMultiline(textStorage: textStorage, editedRange: editedRange)
            return
        }

        let codeTextProcessor = CodeTextProcessor(textStorage: textStorage)
        let parRange = textStorage.mutableString.paragraphRange(for: editedRange)

        if let fencedRange = NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: parRange, string: textStorage) {
            textStorage.removeAttribute(.backgroundColor, range: parRange)
            highlight(textStorage: textStorage, fencedRange: fencedRange, parRange: parRange, delta: delta, editedRange: editedRange)

            if delta == 1,
                textStorage.mutableString.substring(with: editedRange) == "\n",
                textStorage.length >= fencedRange.upperBound + 1,
                textStorage.attribute(.backgroundColor, at: fencedRange.upperBound, effectiveRange: nil) != nil {

                textStorage.removeAttribute(.backgroundColor, range: NSRange(location: fencedRange.upperBound, length: 1))
            }

        } else if UserDefaultsManagement.indentedCodeBlockHighlighting,
            let codeBlockRanges = codeTextProcessor.getCodeBlockRanges(),
            let intersectedRange = codeTextProcessor.getIntersectedRange(range: parRange, ranges: codeBlockRanges) {
            highlight(textStorage: textStorage, indentedRange: codeBlockRanges, intersectedRange: intersectedRange, editedRange: editedRange)
        } else {
            if textStorage.attributedSubstring(from: editedRange).string == "\n" {
                let editedParagraph = textStorage.mutableString.paragraphRange(for: NSRange(location: editedRange.location + 1, length: 0))

                let nextLine = textStorage.attributedSubstring(from: editedParagraph).string
                if !nextLine.startsWith(string: "```") && !nextLine.startsWith(string: "\t") && !nextLine.startsWith(string: "    ") {
                    highlightParagraph(textStorage: textStorage, editedRange: editedParagraph)
                }
            }

            highlightParagraph(textStorage: textStorage, editedRange: editedRange)
        }
    }

    private func highlight(textStorage: NSTextStorage, fencedRange: NSRange, parRange: NSRange, delta: Int, editedRange: NSRange) {
        let code = textStorage.mutableString.substring(with: fencedRange)
        let language = NotesTextProcessor.getLanguage(code)

        NotesTextProcessor.highlightCode(attributedString: textStorage, range: parRange, language: language)

        NotesTextProcessor.highlightFencedBackTick(range: fencedRange, attributedString: textStorage, language: language)

        if delta == 1 {
            let newChar = textStorage.mutableString.substring(with: editedRange)
            let isNewLine = newChar == "\n"

            let backgroundRange =
                isNewLine && parRange.upperBound + 1 <= textStorage.length
                    ? NSRange(parRange.location..<parRange.upperBound + 1)
                    : parRange

            textStorage.addAttribute(.backgroundColor, value: NotesTextProcessor.codeBackground, range: backgroundRange)
        }
    }

    private func highlight(textStorage: NSTextStorage, indentedRange: [NSRange], intersectedRange: NSRange, editedRange: NSRange) {
        let parRange = textStorage.mutableString.paragraphRange(for: editedRange)
        let checkRange = intersectedRange.length < 500 ? intersectedRange : parRange

        NotesTextProcessor.highlightCode(attributedString: textStorage, range: checkRange)
    }

    private func highlightParagraph(textStorage: NSTextStorage, editedRange: NSRange) {
        let codeTextProcessor = CodeTextProcessor(textStorage: textStorage)
        var parRange = textStorage.mutableString.paragraphRange(for: editedRange)
        let paragraph = textStorage.mutableString.substring(with: parRange)

        updateParagraphStyle(range: parRange)

        if paragraph.count == 2, textStorage.attributedSubstring(from: parRange).attribute(.backgroundColor, at: 1, effectiveRange: nil) != nil {
            if let ranges = codeTextProcessor.getCodeBlockRanges(parRange: parRange) {
                let invalidateBackgroundRange =
                    ranges.count == 2
                        ? NSRange(ranges.first!.upperBound..<ranges.last!.location)
                        : parRange

                textStorage.removeAttribute(.backgroundColor, range: invalidateBackgroundRange)

                for range in ranges {
                    NotesTextProcessor.highlightCode(attributedString: textStorage, range: range)
                }
            }
        } else {
            textStorage.removeAttribute(.backgroundColor, range: parRange)
        }

        // Proper paragraph scan for two line markup "==" and "--"
        let prevParagraphLocation = parRange.lowerBound - 1
        if prevParagraphLocation > 0 && (paragraph.starts(with: "==") || paragraph.starts(with: "--")) {
            let prev = textStorage.mutableString.paragraphRange(for: NSRange(location: prevParagraphLocation, length: 0))
            parRange = NSRange(location: prev.lowerBound, length: parRange.upperBound - prev.lowerBound)
        }

        guard let note = EditTextView.note else { return }
        NotesTextProcessor.highlightMarkdown(attributedString: textStorage, paragraphRange: parRange, note: note)
        NotesTextProcessor.checkBackTick(styleApplier: textStorage, paragraphRange: parRange)
    }

    private func highlightMultiline(textStorage: NSTextStorage, editedRange: NSRange) {
        let parRange = textStorage.mutableString.paragraphRange(for: editedRange)
        let codeTextProcessor = CodeTextProcessor(textStorage: textStorage)

        if let fencedRange = NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: parRange, string: textStorage) {
            let code = textStorage.mutableString.substring(with: fencedRange)
            let language = NotesTextProcessor.getLanguage(code)

            NotesTextProcessor.highlightCode(attributedString: textStorage, range: fencedRange, language: language)
            NotesTextProcessor.highlightFencedBackTick(range: fencedRange, attributedString: textStorage)
        } else if UserDefaultsManagement.indentedCodeBlockHighlighting,
            let codeBlockRanges = codeTextProcessor.getCodeBlockRanges(),
            let intersectedRange = codeTextProcessor.getIntersectedRange(range: parRange, ranges: codeBlockRanges) {

            let checkRange = intersectedRange.length > 1000 ? editedRange : intersectedRange
            NotesTextProcessor.highlightCode(attributedString: textStorage, range: checkRange)
        } else {
            guard let note = EditTextView.note else { return }
            NotesTextProcessor.highlightMarkdown(attributedString: textStorage, paragraphRange: parRange, note: note)
            NotesTextProcessor.checkBackTick(styleApplier: textStorage, paragraphRange: parRange)
        }
    }

    private func loadImages(textStorage: NSTextStorage, checkRange: NSRange) {
        var start = checkRange.lowerBound
        var finish = checkRange.upperBound

        if checkRange.upperBound < length {
            finish = checkRange.upperBound + 1
        }

        if checkRange.lowerBound > 1 {
            start = checkRange.lowerBound - 1
        }

        let affectedRange = NSRange(start..<finish)
        textStorage.enumerateAttribute(.attachment, in: affectedRange) { (value, range, _) in
            if let value = value as? NSTextAttachment, textStorage.attribute(.todo, at: range.location, effectiveRange: nil) == nil {
                #if os(iOS)
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = value.isFile() ? .left : .center
                    textStorage.addAttribute(.paragraphStyle, value: paragraph, range: range)
                #endif

                let imageKey = NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.url")
                if let url = textStorage.attribute(imageKey, at: range.location, effectiveRange: nil) as? URL {
                    loadImage(attachment: value, url: url, range: range)
                }
            }
        }
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
                self.addAttribute(.paragraphStyle, value: parStyle, range: parRange)
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
