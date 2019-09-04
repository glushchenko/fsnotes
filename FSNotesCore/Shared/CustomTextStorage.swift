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
        process(range: editedRange, changeInLength: delta)
    }
#else
    public func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int) {

        guard editedMask != .editedAttributes else { return }
        process(range: editedRange, changeInLength: delta)
    }
#endif

    private func process(range editedRange: NSRange, changeInLength delta: Int) {
        guard !EditTextView.isBusyProcessing, let note = EditTextView.note, note.isMarkdown(),
        (editedRange.length != self.length) || !note.isCached || EditTextView.shouldForceRescan else { return }

        if shouldScanСompletely(textStorage: self, editedRange: editedRange) {
            rescanAll()
        } else {
            rescanPartial(delta: delta)
        }

        centerImages()

        EditTextView.shouldForceRescan = false
        EditTextView.lastRemoved = nil
    }

    private func shouldScanСompletely(textStorage: NSTextStorage, editedRange: NSRange) -> Bool {
        if editedRange.length == self.length {
            return true
        }

        let string = textStorage.attributedSubstring(from: editedRange).string
        return
            string == "`"
            || string == "`\n"
            || EditTextView.lastRemoved == "`"
            || (
                EditTextView.shouldForceRescan
                && textStorage.attributedSubstring(from: editedRange).string.contains("```")
            )
    }

    private func rescanAll() {
        guard let note = EditTextView.note else { return }

        removeAttribute(.backgroundColor, range: NSRange(0..<self.length))

        NotesTextProcessor.highlightMarkdown(attributedString: self)
        NotesTextProcessor.highlightFencedAndIndentCodeBlocks(attributedString: self)

        let range = NSRange(0..<self.length)
        let content = attributedSubstring(from: range)

        note.content = NSMutableAttributedString(attributedString: content)
        note.isCached = true
    }

    private func rescanPartial(delta: Int) {
        guard delta == 1 || delta == -1 else {
            highlightMultiline()
            return
        }

        let codeTextProcessor = CodeTextProcessor(textStorage: self)
        let parRange = self.mutableString.paragraphRange(for: editedRange)

        if let fencedRange = NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: parRange, string: self) {
            highlight(fencedRange: fencedRange, parRange: parRange, delta: delta)
        } else if let codeBlockRanges = codeTextProcessor.getCodeBlockRanges(), let intersectedRange = codeTextProcessor.getIntersectedRange(range: parRange, ranges: codeBlockRanges) {
            highlight(indentedRange: codeBlockRanges, intersectedRange: intersectedRange)
        } else {
            highlightParagraph()
        }
    }

    private func highlight(fencedRange: NSRange, parRange: NSRange, delta: Int) {
        let code = attributedSubstring(from: fencedRange).string
        let language = NotesTextProcessor.getLanguage(code)

        NotesTextProcessor.highlightCode(attributedString: self, range: parRange, language: language)

        if delta == 1 {
            let newChar = self.attributedSubstring(from: editedRange).string
            let isNewLine = newChar == "\n"

            let backgroundRange =
                isNewLine && parRange.upperBound + 1 <= self.length
                    ? NSRange(parRange.location..<parRange.upperBound + 1)
                    : parRange

            addAttribute(.backgroundColor, value: NotesTextProcessor.codeBackground, range: backgroundRange)
        }
    }

    private func highlight(indentedRange: [NSRange], intersectedRange: NSRange) {
        let parRange = mutableString.paragraphRange(for: editedRange)
        let paragraph = attributedSubstring(from: parRange).string
        let codeTextProcessor = CodeTextProcessor(textStorage: self)

        if !codeTextProcessor.isCodeBlockParagraph(paragraph) {
            removeAttribute(.backgroundColor, range: NSRange(0..<self.length))
            NotesTextProcessor.highlightMarkdown(attributedString: self)
            NotesTextProcessor.highlightFencedAndIndentCodeBlocks(attributedString: self)
        }

        let checkRange = intersectedRange.length < 500 ? intersectedRange : parRange

        NotesTextProcessor.highlightCode(attributedString: self, range: checkRange)
    }

    private func highlightParagraph() {
        let codeTextProcessor = CodeTextProcessor(textStorage: self)
        var parRange = mutableString.paragraphRange(for: editedRange)
        let paragraph = attributedSubstring(from: parRange).string

        if paragraph.count == 2, attributedSubstring(from: parRange).attribute(.backgroundColor, at: 1, effectiveRange: nil) != nil {
            if let ranges = codeTextProcessor.getCodeBlockRanges(parRange: parRange) {
                let invalidateBackgroundRange =
                    ranges.count == 2
                        ? NSRange(ranges.first!.upperBound..<ranges.last!.location)
                        : parRange

                removeAttribute(.backgroundColor, range: invalidateBackgroundRange)

                for range in ranges {
                    NotesTextProcessor.highlightCode(attributedString: self, range: range)
                }
            }
        } else {
            removeAttribute(.backgroundColor, range: parRange)
        }

        // Proper paragraph scan for two line markup "==" and "--"
        let prevParagraphLocation = parRange.lowerBound - 1
        if prevParagraphLocation > 0 && (paragraph.starts(with: "==") || paragraph.starts(with: "--")) {
            let prev = mutableString.paragraphRange(for: NSRange(location: prevParagraphLocation, length: 0))
            parRange = NSRange(location: prev.lowerBound, length: parRange.upperBound - prev.lowerBound)
        }

        NotesTextProcessor.highlightMarkdown(attributedString: self, paragraphRange: parRange)
        NotesTextProcessor.checkBackTick(styleApplier: self, paragraphRange: parRange)
    }

    private func highlightMultiline() {
        let parRange = self.mutableString.paragraphRange(for: editedRange)
        let codeTextProcessor = CodeTextProcessor(textStorage: self)

        if let fencedRange = NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: parRange, string: self) {
            let code = attributedSubstring(from: fencedRange).string
            let language = NotesTextProcessor.getLanguage(code)

            NotesTextProcessor.highlightCode(attributedString: self, range: parRange, language: language)
            addAttribute(.backgroundColor, value: NotesTextProcessor.codeBackground, range: parRange)
        } else if let codeBlockRanges = codeTextProcessor.getCodeBlockRanges(),
            let intersectedRange = codeTextProcessor.getIntersectedRange(range: parRange, ranges: codeBlockRanges) {
            NotesTextProcessor.highlightCode(attributedString: self, range: intersectedRange)
        } else {
            NotesTextProcessor.highlightMarkdown(attributedString: self, paragraphRange: parRange)
            NotesTextProcessor.checkBackTick(styleApplier: self, paragraphRange: parRange)
            NotesTextProcessor.highlightFencedAndIndentCodeBlocks(attributedString: self)
        }
    }

    private func centerImages() {
        let checkRange = editedRange
        var start = checkRange.lowerBound
        var finish = checkRange.upperBound

        if checkRange.upperBound < length {
            finish = checkRange.upperBound + 1
        }

        if checkRange.lowerBound > 1 {
            start = checkRange.lowerBound - 1
        }

        let affectedRange = NSRange(start..<finish)
        enumerateAttribute(.attachment, in: affectedRange) { (value, range, _) in
            if nil != value as? NSTextAttachment, attribute(.todo, at: range.location, effectiveRange: nil) == nil {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center

                addAttribute(.paragraphStyle, value: paragraph, range: range)
            }
        }
    }
}
