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
        guard let textView = vcEditor else { return }
        
        textView.isScrollPositionSaverLocked = true
        
        defer {
            textView.isScrollPositionSaverLocked = false
        }
        
        guard let position = textView.note?.contentOffset,
              let scrollView = textView.enclosingScrollView else { return }
            
        DispatchQueue.main.async {
            guard let documentView = scrollView.documentView else { return }

            let contentHeight = scrollView.contentView.bounds.height
            let documentHeight = documentView.bounds.height

            let maxY = max(0, documentHeight - contentHeight)

            let clampedY = min(max(position.y, 0), maxY)
            let clampedPoint = CGPoint(x: 0, y: clampedY)

            scrollView.contentView.scroll(to: clampedPoint)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
    
    @objc func scrollViewDidScroll(_ notification: Notification) {
        guard let clipView = notification.object as? NSClipView else { return }
                
        if let textView = vcEditor, !textView.isPreviewEnabled(), !textView.isScrollPositionSaverLocked {
            DispatchQueue.main.async {
                let scrollPosition = clipView.bounds.origin
                textView.note?.contentOffset = scrollPosition
            }
        }
    }
}
