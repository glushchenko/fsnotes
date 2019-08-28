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
        (editedRange.length != textStorage.length) || !note.isCached || EditTextView.shouldForceRescan else { return }

        if editedRange.length == textStorage.length || hasCodeBlock(textStorage: textStorage, editedRange: editedRange) {
            EditTextView.lastRemoved = nil

            NotesTextProcessor.fullScan(note: note, storage: textStorage, range: nil)
            let range = NSRange(0..<textStorage.length)
        note.content =
            NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: range))
            note.isCached = true
        } else {
            let processor = NotesTextProcessor(note: note, storage: textStorage, range: editedRange)
            processor.scanParagraph(loadImages: false)
        }

        if UserDefaultsManagement.codeBlockHighlight, note.isMarkdown() {
            highlightCodeBlock(textStorage: textStorage, editedRange: editedRange, delta: delta)
        }

        centerImages(storage: textStorage, checkRange: editedRange)

        if EditTextView.shouldForceRescan {
            EditTextView.shouldForceRescan = false
        }
    }

    private func hasCodeBlock(textStorage: NSTextStorage, editedRange: NSRange) -> Bool {
        return
            (editedRange.length == 1 && textStorage.attributedSubstring(from: editedRange).string == "`")
            || EditTextView.lastRemoved == "`"
            || (
                EditTextView.shouldForceRescan
                    && textStorage.attributedSubstring(from: editedRange).string.contains("```")
            )
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

    private func scanCodeBlockUp(textStorage: NSTextStorage, location: Int, min: Int? = nil, firstFound: Int? = nil) -> NSRange? {
        var firstFound = firstFound

        if location < 0 {
            if let min = min, let firstFound = firstFound {
                return NSRange(min..<firstFound)
            }
            return nil
        }

        let prevRange = textStorage.mutableString.paragraphRange(for: NSRange(location: location, length: 0))
        let prevAttributed = textStorage.attributedSubstring(from: prevRange)
        let prev = prevAttributed.string

        if NSTextStorage.isCodeBlock(prevAttributed) {
            if firstFound == nil {
                firstFound = prevRange.upperBound - 1
            }

            return scanCodeBlockUp(textStorage: textStorage, location: prevRange.location - 1, min: prevRange.location, firstFound: firstFound)
        } else if prev.trim() == "\n" {
            return scanCodeBlockUp(textStorage: textStorage, location: prevRange.location - 1, min: min, firstFound: firstFound)
        } else {
            if let firstFound = firstFound, let min = min {
                return NSRange(min..<firstFound)
            }

            return nil
        }
    }

    private func scanCodeBlockDown(textStorage: NSTextStorage, location: Int, max: Int? = nil, firstFound: Int? = nil) -> NSRange? {
        var firstFound = firstFound

        if location > textStorage.length {
            if let max = max, let firstFound = firstFound {
                return NSRange(firstFound..<max)
            }
            return nil
        }

        let nextRange = textStorage.mutableString.paragraphRange(for: NSRange(location: location, length: 0))
        let nextAttributed = textStorage.attributedSubstring(from: nextRange)
        let next = nextAttributed.string

        if NSTextStorage.isCodeBlock(nextAttributed) {
            if textStorage.length == nextRange.upperBound {
                if let firstFound = firstFound {
                    return NSRange(firstFound..<nextRange.upperBound)
                }
            }

            if firstFound == nil {
                firstFound = nextRange.location
            }

            return scanCodeBlockDown(textStorage: textStorage, location: nextRange.upperBound, max: nextRange.upperBound - 1, firstFound: firstFound)
        } else if next.trim() == "\n" {
            if textStorage.length == nextRange.upperBound {
                if let max = max, let firstFound = firstFound {
                    return NSRange(firstFound..<max)
                }
            }

            return scanCodeBlockDown(textStorage: textStorage, location: nextRange.upperBound, max: max, firstFound: firstFound)
        } else {
            if let max = max, let firstFound = firstFound {
                return NSRange(firstFound..<max)
            }
            return nil
        }
    }

    public static func isCodeBlock(_ attributedString: NSAttributedString) -> Bool {
        if attributedString.string.starts(with: "\t") || attributedString.string.starts(with: "    ") {
            let clean = attributedString.string.trim()

            guard TextFormatter.getAutocompleteCharsMatch(string: clean) == nil && TextFormatter.getAutocompleteDigitsMatch(string: clean) == nil else {
                return false
            }

            var hasTodo = false
            attributedString.enumerateAttribute(.todo, in: NSRange(0..<attributedString.length), options: []) { (value, _, stop) -> Void in
                guard value != nil else { return }

                hasTodo = true
                stop.pointee = true
            }

            if hasTodo {
                return false
            }

            return true
        }

        return false
    }

    private func getCodeBlockRange(textStorage: NSTextStorage, parRange: NSRange, delta: Int) -> [NSRange]? {
        let attributedParagraph = textStorage.attributedSubstring(from: parRange)
        let paragraph = attributedParagraph.string
        let isCodeParagraph = NSTextStorage.isCodeBlock(attributedParagraph)

        let min = scanCodeBlockUp(textStorage: textStorage, location: parRange.location - 1)
        let max = scanCodeBlockDown(textStorage: textStorage, location: parRange.upperBound)

        if delta == -1, let min = min, let max = max {
            let invalidate = NSRange(min.location..<max.upperBound)
            textStorage.removeAttribute(.paragraphStyle, range: invalidate)
            textStorage.fixAttributes(in: invalidate)
        }

        if let min = min, let max = max {
            if isCodeParagraph || paragraph.trim() == "\n" {
                return [NSRange(min.location..<max.upperBound)]
            } else {
                return [min, max]
            }
        } else if let min = min {
            if isCodeParagraph {
                return [NSRange(min.location..<parRange.upperBound - 1)]
            } else {
                return [min]
            }
        } else if let max = max {
            if isCodeParagraph {
                return [NSRange(parRange.location..<max.upperBound)]
            } else {
                return [max]
            }
        } else if isCodeParagraph {
            return [parRange]
        }

        return nil
    }

    private func highlightCodeBlock(textStorage: NSTextStorage, editedRange: NSRange, delta: Int) {
        if let fencedRange = NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: editedRange, string: textStorage) {
            if textStorage.attributedSubstring(from: editedRange).string == "\n"
                && fencedRange.upperBound == editedRange.upperBound
                && textStorage.length >= editedRange.upperBound + 1 {
                let drop = NSRange(location: editedRange.upperBound, length: 1)
                textStorage.removeAttribute(.paragraphStyle, range: drop)
                textStorage.fixAttributes(in: drop)
            }
        } else {
            if delta == -1 && editedRange.location + 1 <= textStorage.length {
                let drop = NSRange(location: editedRange.location, length: 1)
                textStorage.removeAttribute(.paragraphStyle, range: drop)
                textStorage.fixAttributes(in: drop)
            }

            let firstRange = NSRange(location: editedRange.location, length: 0)
            let paragraphRange = textStorage.mutableString.paragraphRange(for: firstRange)

            if let ranges = getCodeBlockRange(textStorage: textStorage, parRange: paragraphRange, delta: delta) {
                for range in ranges {
                    if ranges.count == 1 {
                        var hasTodo = false
                        textStorage.enumerateAttribute(.todo, in: range, options: []) { (value, _, stop) -> Void in
                            guard value != nil else { return }

                            hasTodo = true
                            stop.pointee = true
                        }

                        if !hasTodo {
                            NotesTextProcessor.highlight(range: range, attributedString: textStorage)
                        }
                    }

                    let style = TextFormatter.getCodeParagraphStyle()
                    textStorage.addAttribute(.paragraphStyle, value: style, range: range)
                    textStorage.fixAttributes(in: range)
                }
            }
        }
    }
}
