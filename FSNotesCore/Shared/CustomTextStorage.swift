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
        process(textStorage, range: editedRange, changeInLength: delta)
    }
#else
    public func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int) {

        guard editedMask != .editedAttributes else { return }
        process(textStorage, range: editedRange, changeInLength: delta)
    }
#endif

    private func process(_ textStorage: NSTextStorage,
                         range editedRange: NSRange,
                         changeInLength delta: Int) {

        guard !EditTextView.isBusyProcessing, let note = EditTextView.note, note.isMarkdown(),
        (editedRange.length != textStorage.length) || !note.isCached || EditTextView.isPasteOperation else { return }

        if editedRange.length == textStorage.length {
            NotesTextProcessor.fullScan(note: note, storage: textStorage, range: nil)
            let range = NSRange(0..<textStorage.length)
        note.content =
            NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: range))
            note.isCached = true
        } else {
            let processor = NotesTextProcessor(note: note, storage: textStorage, range: editedRange)
            processor.scanParagraph(loadImages: false)
        }

        centerImages(storage: textStorage, checkRange: editedRange)

        if EditTextView.isPasteOperation {
            EditTextView.isPasteOperation = false
        }
    }

    private func getCodeRanges(string: String, length: Int) -> ([NSRange], [NSRange])? {
        var fencedRanges = [NSRange]()
        if let ranges = NotesTextProcessor.getAllFencedCodeBlockRanges(string: string, length: length) {
            fencedRanges = ranges
        }

        var indentedRanges = [NSRange]()
        if let ranges = NotesTextProcessor.getAllIndentedCodeBlockRanges(string: string, length: length) {
            indentedRanges = ranges
        }

        return (fencedRanges, indentedRanges)
    }

    public func isCodeBlock(paragraph: String) -> Bool {
        if paragraph.starts(with: "\t") || paragraph.starts(with: "    ") {
            guard TextFormatter.getAutocompleteCharsMatch(string: string) == nil
                && TextFormatter.getAutocompleteDigitsMatch(string: string) == nil else {
                    return false
            }

            return true
        }

        return false
    }

    public func isNewLine(editedRange: NSRange) -> Bool {
        return (self.attributedSubstring(from: editedRange).string == "\n")
    }

    private func isInserting(delta: Int) -> Bool {
        return (delta == 1)
    }

    private func isRemoving(delta: Int) -> Bool {
        return (delta == -1)
    }

    private func highlightCodeBlock(editedRange: NSRange) {
        let paragraphRange = mutableString.paragraphRange(for: editedRange)
        let paragraph = attributedSubstring(from: paragraphRange).string

        if isCodeBlock(paragraph: paragraph) {
            let attributes = TextFormatter.getCodeBlockAttributes()
            addAttributes(attributes, range: paragraphRange)
        }
    }

    private func centerImages(storage: NSTextStorage, checkRange: NSRange) {
        var start = checkRange.lowerBound
        var finish = checkRange.upperBound

        if checkRange.upperBound < storage.length {
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
