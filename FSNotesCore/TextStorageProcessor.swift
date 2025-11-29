//
//  TextStorageProcessor.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 26.06.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

#if os(OSX)
import Cocoa
import AVKit
#else
import UIKit
import AVKit
#endif

class TextStorageProcessor: NSObject, NSTextStorageDelegate {
    public var editor: EditTextView?
    public var detector = CodeBlockDetector()

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
        guard let note = editor?.note, textStorage.length > 0 else { return }

        defer {
            loadImages(textStorage: textStorage, checkRange: editedRange)
            textStorage.updateParagraphStyle(range: editedRange)
        }

        if note.content.length == textStorage.length && (
            editedRange.length > 300000 || note.content.string.fnv1a == note.cacheHash
        ) { return }

        let codeBlockRanges = detector.findCodeBlocks(in: textStorage)
        let paragraphRange = (textStorage.string as NSString).paragraphRange(for: editedRange)

        NotesTextProcessor.highlightMarkdown(attributedString: textStorage, paragraphRange: paragraphRange, codeBlockRanges: codeBlockRanges)

        // Code block founds
        var result = detector.codeBlocks(textStorage: textStorage, editedRange: editedRange, delta: delta, newRanges: codeBlockRanges)
        note.codeBlockRangesCache = codeBlockRanges

        // Highlight code block end (```), that wiped previously in highlightMarkdown
        for range in codeBlockRanges {
            if NSIntersectionRange(range, paragraphRange).length > 0 {
                if result.edited == nil {
                    result.code?.append(range)
                }
            }
        }

        if let ranges = result.code {
            for range in ranges {
                // print("added code block \(range)")
                let language = NotesTextProcessor.getLanguage(from: textStorage, startingAt: range.location)

                NotesTextProcessor
                    .getHighlighter()
                    .highlight(in: textStorage, range: range, language: language)
            }
        }

        if let editedBlock = result.edited, let editedParagraph = result.editedParagraph {
            // print("edited paragraph \(editedParagraph) in block \(editedBlock)")
            let language = NotesTextProcessor.getLanguage(from: textStorage, startingAt: editedBlock.location)

            NotesTextProcessor
                .getHighlighter()
                .highlight(in: textStorage, range: editedParagraph, language: language, skipTicks: true)
        }

        if let ranges = result.md {
            for range in ranges {
                // print("became markdown \(range)")
                let safeRange = safeRange(range, in: textStorage)
                NotesTextProcessor.highlightMarkdown(attributedString: textStorage, paragraphRange: safeRange)
            }
        }
    }

    private func loadImages(textStorage: NSTextStorage, checkRange: NSRange) {
        guard let note = editor?.note else { return }

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
            guard let attachment = value as? NSTextAttachment,
                  let meta = textStorage.getMeta(at: range.location) else { return }

            var url = meta.url

            // 1. check data to save (copy/paste, drag/drop)
            if let data = textStorage.getData(at: range.location),
               let result = note.save(data: data, preferredName: meta.url.lastPathComponent) {

                textStorage.addAttributes([
                    .attachmentUrl: result.1,
                    .attachmentPath: result.0
                ], range: range)

                url = result.1
            }

            // 2. load
            let maxWidth = getImageMaxWidth()
            loadImage(attachment: attachment, url: url, range: range, textStorage: textStorage, maxWidth: maxWidth)
        }
    }

    public func loadImage(attachment: NSTextAttachment, url: URL, range: NSRange, textStorage: NSTextStorage, maxWidth: CGFloat) {
        editor?.imagesLoaderQueue.addOperation {
            var image: PlatformImage?
            var size: CGSize?

            if url.isMedia {
                let imageSize = url.getBorderSize(maxWidth: maxWidth)

                size = imageSize
                image = NoteAttachment.getImage(url: url, size: imageSize)
            } else {
                let attachment = NoteAttachment(url: url)
                if let attachmentImage = attachment.getAttachmentImage() {
                    size = attachmentImage.size
                    image = attachmentImage
                }
            }

            DispatchQueue.main.async {
                guard let manager = self.editor?.layoutManager as? NSLayoutManager else { return }

            #if os(iOS)
                attachment.image = image
                if let size = size {
                    attachment.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                }

                // iOS only unknown behaviour
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = url.isMedia ? .center : .left
                textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            #elseif os(OSX)
                guard let container = self.editor?.textContainer,
                      let attachmentImage = image,
                      let size = size else { return }

                let cell = FSNTextAttachmentCell(textContainer: container, image: attachmentImage)
                cell.image?.size = size
                attachment.image = nil
                attachment.attachmentCell = cell
                attachment.bounds = NSRect(x: 0, y: 0, width: size.width, height: size.height)
            #endif

                let safe = self.safeRange(range, in: textStorage)

                textStorage.edited(.editedAttributes, range: safe, changeInLength: 0)
                manager.invalidateLayout(forCharacterRange: safe, actualCharacterRange: nil)
            }
        }
    }

    private func getImageMaxWidth() -> CGFloat {
        #if os(iOS)
            return UIApplication.getVC().view.frame.width - 35
        #else
            return CGFloat(UserDefaultsManagement.imagesWidth)
        #endif
    }

    private func safeRange(_ range: NSRange, in textStorage: NSTextStorage) -> NSRange {
        let storageLength = textStorage.length
        let loc = min(max(0, range.location), storageLength)
        let end = min(max(0, range.location + range.length), storageLength)
        return NSRange(location: loc, length: end - loc)
    }
}
