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

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
        let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1),
                                              in: textContainer)

        textView.scroll(rect.origin)
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
