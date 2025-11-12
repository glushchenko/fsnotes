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
                NotesTextProcessor.highlightMarkdown(attributedString: textStorage, paragraphRange: range)
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
                  var meta = attachment.getMeta() else { return }

            if let result = note.save(attachment: meta) {
                attachment.saveMetaData(url: result.1, path: result.0, title: meta.title)
                meta.url = result.1
            }

            loadImage(attachment: attachment, url: meta.url, range: range, textStorage: textStorage)
        }
    }

#if os(OSX)
    public func loadImage(attachment: NSTextAttachment, url: URL, range: NSRange, textStorage: NSTextStorage) {
        editor?.imagesLoaderQueue.addOperation {
            var image: NSImage?
            var size: NSSize?

            if url.isImage {
                let imageSize = NoteAttachment.getSize(url: url)
                size = NoteAttachment.getSize(width: imageSize.width, height: imageSize.height)

                if let size = size {
                    let retinaSize = CGSize(width: size.width * 2, height: size.height * 2)
                    image = NoteAttachment.getImage(url: url, size: retinaSize)
                }
            } else {
                let attachment = NoteAttachment(title: "", path: "", url: url)
                let heigth = UserDefaultsManagement.noteFont.getAttachmentHeight()
                let text = attachment.getImageText()
                let width = attachment.getImageWidth(text: text)
                size = NSSize(width: width, height: heigth)
                let imageSize = NSSize(width: width, height: heigth)
                image = attachment.imageFromText(text: text, imageSize: imageSize)
            }

            DispatchQueue.main.async {
                guard let container = self.editor?.textContainer,
                      let attachmentImage = image,
                      let size = size else { return }

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

                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = url.isImage ? .center : .left

                    textStorage.safeAddAttribute(.paragraphStyle, value: paragraph, range: range)
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
