//
//  EditorViewController+ScrollPosition.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 22.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation
import AppKit

extension EditorViewController {

    // YAML metadata is replaced by a rendered header before Markdown parsing.
    private func previewLineOffset(for note: Note) -> Int {
        let source = note.content.string
        let rendered = note.cleanMetaData(content: source)
        return source.components(separatedBy: "\n").count - rendered.components(separatedBy: "\n").count
    }

    func previewSourceLine() -> Int? {
        guard let textView = vcEditor, let note = textView.note,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView,
              textView.string.utf16.count > 0 else { return nil }

        var visibleRect = scrollView.contentView.bounds
        visibleRect.origin.x -= textView.textContainerOrigin.x
        visibleRect.origin.y -= textView.textContainerOrigin.y
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard glyphRange.location < layoutManager.numberOfGlyphs else { return nil }
        let index = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        note.scrollPosition = index
        let prefix = (textView.string as NSString).substring(to: index)
        return max(1, prefix.components(separatedBy: "\n").count - previewLineOffset(for: note))
    }

    func restoreEditorSourceLine(_ line: Int) {
        guard let textView = vcEditor, let note = textView.note else { return }
        let sourceLine = max(1, line + previewLineOffset(for: note))
        let lines = note.content.string.components(separatedBy: "\n")
        let precedingLines = lines.prefix(min(sourceLine - 1, lines.count - 1))
        note.scrollPosition = precedingLines.reduce(0) { $0 + $1.utf16.count + 1 }
        textView.isScrollPositionSaverLocked = true
        restoreScrollPosition()
    }
    
    func initScrollObserver() {
        if let textView = vcEditor, let scrollView = textView.enclosingScrollView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewDidScroll),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
            
            scrollView.contentView.postsBoundsChangedNotifications = true
        }
    }
    
    func restoreScrollPosition() {
        guard let textView = vcEditor,
              let charIndex = textView.note?.scrollPosition,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            vcEditor?.isScrollPositionSaverLocked = false
            return
        }
                    
        layoutManager.ensureLayout(for: textContainer)

        guard textView.string.utf16.count > 0 else {
            textView.isScrollPositionSaverLocked = false
            return
        }
        let index = min(max(0, charIndex), textView.string.utf16.count - 1)
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: index)
        let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1),
                                              in: textContainer)

        textView.scroll(NSPoint(x: 0, y: rect.origin.y + textView.textContainerOrigin.y))
        textView.isScrollPositionSaverLocked = false
    }
    
    @objc func scrollViewDidScroll(_ notification: Notification) {
        guard notification.object as? NSClipView != nil else { return }
                
        if let textView = vcEditor, !textView.isPreviewEnabled(), !textView.isScrollPositionSaverLocked {
            guard
                let layoutManager = textView.layoutManager,
                let textContainer = textView.textContainer
            else { return }

            let visibleRect = textView.enclosingScrollView!.contentView.bounds
            let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect,
                                                       in: textContainer)

            textView.note?.scrollPosition = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        }
    }
}
