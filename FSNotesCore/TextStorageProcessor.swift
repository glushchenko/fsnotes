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
    public var isRendering = false

    /// Hide syntax characters by making them invisible (clear color) and
    /// collapsing their width (negative kern). Preserves existing font so
    /// the cursor inherits correct height. Mirrors the approach in
    /// NotesTextProcessor.highlightMarkdown's hideSyntaxIfNecessary.
    func hideSyntaxRange(_ range: NSRange, in textStorage: NSTextStorage) {
        let nsString = textStorage.string as NSString
        textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
        for i in 0..<range.length {
            let charPos = range.location + i
            guard charPos < nsString.length else { break }
            let charStr = nsString.substring(with: NSRange(location: charPos, length: 1))
            if let charFont = textStorage.attribute(.font, at: charPos, effectiveRange: nil) as? NSFont {
                let charWidth = (charStr as NSString).size(withAttributes: [.font: charFont]).width
                textStorage.addAttribute(.kern, value: -charWidth, range: NSRange(location: charPos, length: 1))
            }
        }
    }

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
            
        if editedMask.contains(.editedCharacters), delta < 0 {
            if let layoutManager = textStorage.layoutManagers.first,
               let textContainer = layoutManager.textContainers.first,
               let textView = textContainer.textView {
                textView.needsDisplay = true
            }
        }
    }
#endif

    private func process(textStorage: NSTextStorage, range editedRange: NSRange, changeInLength delta: Int) {
        guard let note = editor?.note, textStorage.length > 0 else { return }
        guard !isRendering else { return }

        defer {
            loadImages(textStorage: textStorage, checkRange: editedRange)
            textStorage.updateParagraphStyle(range: editedRange)
        }

        if note.content.length == textStorage.length && (
            note.content.string.fnv1a == note.cacheHash
        ) { return }
        
        // Full load
        if editedRange.length == textStorage.length {
            NotesTextProcessor.highlight(attributedString: textStorage)
            return
        }

        let codeBlockRanges = detector.findCodeBlocks(in: textStorage)
        let paragraphRange = (textStorage.string as NSString).paragraphRange(for: editedRange)

        NotesTextProcessor.highlightMarkdown(attributedString: textStorage, paragraphRange: paragraphRange, codeBlockRanges: codeBlockRanges)

        // Code block founds
        var result = detector.codeBlocks(textStorage: textStorage, editedRange: editedRange, delta: delta, newRanges: codeBlockRanges)
        note.codeBlockRangesCache = codeBlockRanges

        // Hide code fence lines (``` ) in WYSIWYG mode
        if NotesTextProcessor.hideSyntax {
            let string = textStorage.string as NSString

            for codeRange in codeBlockRanges {
                guard codeRange.location < string.length, NSMaxRange(codeRange) <= string.length else { continue }
                let firstLineRange = string.lineRange(for: NSRange(location: codeRange.location, length: 0))
                let firstLine = string.substring(with: firstLineRange).trimmingCharacters(in: .whitespacesAndNewlines)

                // Hide opening fence: only the backticks, keep the language name visible
                if firstLineRange.length > 0 {
                    let backtickCount = min(3, firstLineRange.length)
                    let backtickRange = NSRange(location: firstLineRange.location, length: backtickCount)
                    self.hideSyntaxRange(backtickRange, in: textStorage)

                    // If it's a special block (mermaid/math), hide the language name too
                    if firstLine.hasPrefix("```mermaid") || firstLine.hasPrefix("```math") || firstLine.hasPrefix("```latex") {
                        self.hideSyntaxRange(firstLineRange, in: textStorage)
                    }
                }

                // Hide closing fence line entirely
                let lastCharLoc = max(codeRange.location, NSMaxRange(codeRange) - 1)
                let lastLineRange = string.lineRange(for: NSRange(location: lastCharLoc, length: 0))
                if lastLineRange.location > firstLineRange.location && lastLineRange.length > 0 {
                    self.hideSyntaxRange(lastLineRange, in: textStorage)
                }
            }
        }

        // Render mermaid/math blocks as inline images in WYSIWYG mode
        #if os(OSX)
        renderSpecialCodeBlocks(textStorage: textStorage, codeBlockRanges: codeBlockRanges)
        #endif

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
                NotesTextProcessor
                    .getHighlighter()
                    .highlight(in: textStorage, fullRange: range)
            }
        }

        if let editedBlock = result.edited, let editedParagraph = result.editedParagraph {
            NotesTextProcessor
                .getHighlighter()
                .highlight(in: textStorage, fullRange: editedBlock, editedRange: editedParagraph)
        }

        if let ranges = result.md {
            for range in ranges {
                let safeRange = safeRange(range, in: textStorage)
                NotesTextProcessor.resetFont(attributedString: textStorage, paragraphRange: safeRange)
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

    #if os(OSX)
    /// Render mermaid/math code blocks as inline images in WYSIWYG mode
    public func renderSpecialCodeBlocks(textStorage: NSTextStorage, codeBlockRanges: [NSRange]) {
        guard NotesTextProcessor.hideSyntax else { return }
        let string = textStorage.string as NSString
        NSLog("[renderSpecialCodeBlocks] Called with \(codeBlockRanges.count) code block ranges")
        let debugLog = "/tmp/fsnotes_render_debug.log"
        let msg0 = "[\(Date())] renderSpecialCodeBlocks called with \(codeBlockRanges.count) ranges, hideSyntax=\(NotesTextProcessor.hideSyntax)\n"
        if let fh = FileHandle(forWritingAtPath: debugLog) { fh.seekToEndOfFile(); fh.write(msg0.data(using: .utf8)!); fh.closeFile() }
        else { FileManager.default.createFile(atPath: debugLog, contents: msg0.data(using: .utf8)) }

        for codeRange in codeBlockRanges {
            guard codeRange.location < string.length, NSMaxRange(codeRange) <= string.length else { continue }

            let firstLineRange = string.lineRange(for: NSRange(location: codeRange.location, length: 0))
            let firstLine = string.substring(with: firstLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            NSLog("[renderSpecialCodeBlocks] First line: '\(firstLine)'")

            var blockType: BlockRenderer.BlockType?
            if firstLine.hasPrefix("```mermaid") {
                blockType = .mermaid
            } else if firstLine.hasPrefix("```math") || firstLine.hasPrefix("```latex") {
                blockType = .math
            }

            guard let type = blockType else { continue }

            // Extract the source content (between fences)
            let afterFirstLine = NSMaxRange(firstLineRange)
            let lastCharLoc = max(codeRange.location, NSMaxRange(codeRange) - 1)
            let lastLineRange = string.lineRange(for: NSRange(location: lastCharLoc, length: 0))
            let contentEnd = lastLineRange.location

            guard afterFirstLine < contentEnd else { continue }
            let contentRange = NSRange(location: afterFirstLine, length: contentEnd - afterFirstLine)
            let source = string.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !source.isEmpty else { continue }

            // Check if already rendered (avoid re-rendering on every keystroke)
            if textStorage.attribute(.renderedBlockSource, at: codeRange.location, effectiveRange: nil) as? String == source {
                continue
            }

            let maxWidth = getImageMaxWidth()

            // Capture the full original markdown (fences + content) for restoration on click
            let originalMarkdown = string.substring(with: codeRange)

            BlockRenderer.render(source: source, type: type, maxWidth: maxWidth) { [weak self] image in
                guard let image = image, let self = self else { return }

                DispatchQueue.main.async {
                    guard codeRange.location < textStorage.length,
                          NSMaxRange(codeRange) <= textStorage.length else { return }

                    // Verify the text hasn't changed under us
                    let currentText = (textStorage.string as NSString).substring(with: codeRange)
                    guard currentText.contains(source.prefix(20)) else { return }

                    // Replace the entire code block with a rendered image attachment
                    let attachment = NSTextAttachment()
                    let cell = NSTextAttachmentCell(imageCell: image)
                    let scale = min(maxWidth / image.size.width, 1.0)
                    let scaledSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
                    cell.image?.size = scaledSize
                    attachment.attachmentCell = cell
                    attachment.bounds = NSRect(origin: .zero, size: scaledSize)

                    let attachmentString = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
                    let attRange = NSRange(location: 0, length: attachmentString.length)
                    attachmentString.addAttributes([
                        .renderedBlockSource: source,
                        .renderedBlockType: type == .mermaid ? "mermaid" : "math",
                        .renderedBlockOriginalMarkdown: originalMarkdown
                    ], range: attRange)
                    // Clear code block background so no border appears
                    attachmentString.removeAttribute(.backgroundColor, range: attRange)

                    // Temporarily disable processing to avoid re-highlight cycle
                    self.isRendering = true
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: codeRange, with: attachmentString)
                    // Also clear background on the replaced range in storage
                    let replacedRange = NSRange(location: codeRange.location, length: attachmentString.length)
                    if replacedRange.location + replacedRange.length <= textStorage.length {
                        textStorage.removeAttribute(.backgroundColor, range: replacedRange)
                    }
                    textStorage.endEditing()
                    self.isRendering = false
                }
            }
        }
    }
    #endif

    private func getImageMaxWidth() -> CGFloat {
        #if os(iOS)
            return UIApplication.getVC().view.frame.width - 35
        #else
            if let editorWidth = editor?.enclosingScrollView?.contentView.bounds.width {
                return editorWidth - 40 // margin for padding
            }
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
