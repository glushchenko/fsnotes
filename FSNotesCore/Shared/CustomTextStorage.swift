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

    public func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int) {

        guard let note = EditTextView.note, note.isMarkdown(),
            (editedRange.length != textStorage.length) || !note.isCached else { return }

        note.isCached = true

        if self.isInserting(delta: delta) {
            let paragraphRange = (self.string as NSString).paragraphRange(for: editedRange)
            let paragraph = self.attributedSubstring(from: paragraphRange).string

            if isNewLine(editedRange: editedRange) {
                return
            }

            if isCodeBlock(paragraph: paragraph) {
                let attributes = TextFormatter.getCodeBlockAttributes()

                addAttributes(attributes, range: paragraphRange)

            }

        } else if isRemoving(delta: delta) {
            highlightCodeBlock(editedRange: editedRange)
        }

        let processor = NotesTextProcessor(note: note, storage: textStorage, range: editedRange)
        processor.scanParagraph(loadImages: false, async: false)
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
        let paragraphRange = (self.string as NSString).paragraphRange(for: editedRange)

        let paragraph = self.attributedSubstring(from: paragraphRange).string

        if isCodeBlock(paragraph: paragraph) {
            let attributes = TextFormatter.getCodeBlockAttributes()
            addAttributes(attributes, range: paragraphRange)
        }
    }

}
