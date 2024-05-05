//
//  TextStorageProcessor.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 26.06.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

#if os(OSX)
import AppKit
import Cocoa
import AVKit
#else
import UIKit
import AVKit
#endif

class TextStorageProcessor: NSObject, NSTextStorageDelegate {
    public var shouldForceRescan: Bool?
    public var lastRemoved: String?
    public var editor: EditTextView?

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
        guard let note = editor?.note, note.isMarkdown() else { return }
        guard delta != 0 || shouldForceRescan == true else { return }

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
            textStorage.updateParagraphStyle()
        }

        loadImages(textStorage: textStorage, checkRange: editedRange)

        shouldForceRescan = false
        lastRemoved = nil
    }

    private func shouldScanСompletely(textStorage: NSTextStorage, editedRange: NSRange) -> Bool {
        if editedRange.length == textStorage.length {
            return true
        }

        let string = textStorage.mutableString.substring(with: editedRange)

        return
            string == "`"
            || string == "`\n"
            || lastRemoved == "`"
            || (
                shouldForceRescan == true
                && string.contains("```")
            )
    }

    private func rescanAll(textStorage: NSTextStorage) {
        guard let note = editor?.note else { return }

        let range = NSRange(0..<textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: range)

        NotesTextProcessor.highlightMarkdown(attributedString: textStorage, note: note)
        NotesTextProcessor.highlightFencedAndIndentCodeBlocks(attributedString: textStorage)

        textStorage.updateParagraphStyle()
    }

    private func rescanPartial(textStorage: NSTextStorage, delta: Int, editedRange: NSRange) {

        // Rescan header yaml

        var checkAt = editedRange.location - 1
        if checkAt < 0 {
            checkAt = 0
        }

        if let yamlRange = textStorage.attribute(.yamlBlock, at: checkAt, effectiveRange: nil) as? NSRange {
            let fixRange = NSRange(location: 0, length: yamlRange.length + delta)
            textStorage.removeAttribute(.yamlBlock, range: fixRange)
            textStorage.removeAttribute(.foregroundColor, range: fixRange)
        }

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

        textStorage.updateParagraphStyle(range: parRange)

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

        guard let note = editor?.note else { return }
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
            guard let note = editor?.note else { return }
            NotesTextProcessor.highlightMarkdown(attributedString: textStorage, paragraphRange: parRange, note: note)
            NotesTextProcessor.checkBackTick(styleApplier: textStorage, paragraphRange: parRange)
            textStorage.updateParagraphStyle(range: parRange)
        }
    }

    private func loadImages(textStorage: NSTextStorage, checkRange: NSRange) {
        var start = checkRange.lowerBound
        var finish = checkRange.upperBound

        if checkRange.upperBound < textStorage.length {
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
                    loadImage(attachment: value, url: url, range: range, textStorage: textStorage)
                }
            }
        }
    }

#if os(OSX)
    public func loadImage(attachment: NSTextAttachment, url: URL, range: NSRange, textStorage: NSTextStorage) {
        editor?.imagesLoaderQueue.addOperation {
            guard url.isImage else { return }

            let size = attachment.bounds.size
            let retinaSize = CGSize(width: size.width * 2, height: size.height * 2)
            let image = NoteAttachment.getImage(url: url, size: retinaSize)

            DispatchQueue.main.async {
                guard let container = self.editor?.textContainer,
                      let attachmentImage = image else { return }

                let cell = FSNTextAttachmentCell(textContainer: container, image: attachmentImage)
                cell.image?.size = size
                attachment.image = nil
                attachment.attachmentCell = cell
                attachment.bounds = NSRect(x: 0, y: 0, width: size.width, height: size.height)

                if let manager = self.editor?.layoutManager {
                    if #available(OSX 10.13, *) {
                    } else {
                        if textStorage.mutableString.length >= range.upperBound {
                            manager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                        }
                    }

                    manager.invalidateDisplay(forCharacterRange: range)
                }
            }
        }
    }
#else

    public func loadImage(attachment: NSTextAttachment, url: URL, range: NSRange, textStorage: NSTextStorage) {
        editor?.imagesLoaderQueue.addOperation {
            guard let size = attachment.image?.size else { return }

            let scale = UIScreen.main.scale
            let retinaSize = CGSize(width: size.width * scale, height: size.height * scale)

            if let image = NoteAttachment.getImage(url: url, size: retinaSize) {
                attachment.image = image
            }

            DispatchQueue.main.async {
                if let manager = self.editor?.layoutManager as? NSLayoutManager {
                    manager.invalidateDisplay(forCharacterRange: range)
                }
            }
        }
    }
#endif
}
