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
        guard !EditTextView.isBusyProcessing, let note = EditTextView.note, note.isMarkdown(),
        (editedRange.length != textStorage.length) || !note.isCached || EditTextView.shouldForceRescan else { return }

        if shouldScanСompletely(textStorage: textStorage, editedRange: editedRange) {
            rescanAll(textStorage: textStorage)
        } else {
            rescanPartial(textStorage: textStorage, delta: delta, editedRange: editedRange)
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

        removeAttribute(.backgroundColor, range: NSRange(0..<textStorage.length))

        NotesTextProcessor.highlightMarkdown(attributedString: textStorage)
        NotesTextProcessor.highlightFencedAndIndentCodeBlocks(attributedString: textStorage)

        let range = NSRange(0..<textStorage.length)
        let content = textStorage.attributedSubstring(from: range)

        note.content = NSMutableAttributedString(attributedString: content)
        note.isCached = true
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

        } else if let codeBlockRanges = codeTextProcessor.getCodeBlockRanges(), let intersectedRange = codeTextProcessor.getIntersectedRange(range: parRange, ranges: codeBlockRanges) {
            highlight(textStorage: textStorage, indentedRange: codeBlockRanges, intersectedRange: intersectedRange, editedRange: editedRange)
        } else {
            highlightParagraph(textStorage: textStorage, editedRange: editedRange)
        }
    }

    private func highlight(textStorage: NSTextStorage, fencedRange: NSRange, parRange: NSRange, delta: Int, editedRange: NSRange) {
        let code = textStorage.mutableString.substring(with: fencedRange)
        let language = NotesTextProcessor.getLanguage(code)

        NotesTextProcessor.highlightCode(attributedString: textStorage, range: parRange, language: language)

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

        NotesTextProcessor.highlightMarkdown(attributedString: textStorage, paragraphRange: parRange)
        NotesTextProcessor.checkBackTick(styleApplier: textStorage, paragraphRange: parRange)
    }

    private func highlightMultiline(textStorage: NSTextStorage, editedRange: NSRange) {
        let parRange = textStorage.mutableString.paragraphRange(for: editedRange)
        let codeTextProcessor = CodeTextProcessor(textStorage: textStorage)

        if let fencedRange = NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: parRange, string: textStorage) {
            let code = textStorage.mutableString.substring(with: fencedRange)
            let language = NotesTextProcessor.getLanguage(code)
            NotesTextProcessor.highlightCode(attributedString: textStorage, range: parRange, language: language)
            textStorage.addAttribute(.backgroundColor, value: NotesTextProcessor.codeBackground, range: parRange)
        } else if let codeBlockRanges = codeTextProcessor.getCodeBlockRanges(),
            let intersectedRange = codeTextProcessor.getIntersectedRange(range: parRange, ranges: codeBlockRanges) {
            let checkRange = intersectedRange.length > 1000 ? editedRange : intersectedRange
            NotesTextProcessor.highlightCode(attributedString: textStorage, range: checkRange)
        } else {
            NotesTextProcessor.highlightMarkdown(attributedString: textStorage, paragraphRange: parRange)
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
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center

                textStorage.addAttribute(.paragraphStyle, value: paragraph, range: range)

                #if os(iOS)
                let imageKey = NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.url")
                if let url = textStorage.attribute(imageKey, at: range.location, effectiveRange: nil) as? URL {
                    print("LOAD URL:")
                    print(url)
                    loadImage(attachment: value, url: url, range: range)
                }
                #endif
            }
        }
    }
}
