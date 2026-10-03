//
//  EditorScrollView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class EditorScrollView: NSScrollView {
    private var contentInsetBeforeFind: CGFloat?

    override var isFindBarVisible: Bool {
        get {
            return super.isFindBarVisible
        }
        set {
            let clip = contentView

            // Keep the editor below the find bar while it is visible.
            if newValue {
                if contentInsetBeforeFind == nil {
                    contentInsetBeforeFind = clip.contentInsets.top
                }
                clip.contentInsets.top = 60
                documentView?.scroll(NSPoint(x: 0, y: -60))
            }

            super.isFindBarVisible = newValue

            if !newValue, let previousInset = contentInsetBeforeFind {
                clip.contentInsets.top = previousInset
                contentInsetBeforeFind = nil

                // Remove any overscroll left by the find bar's extra inset.
                clip.scroll(to: clip.constrainBoundsRect(clip.bounds).origin)
                reflectScrolledClipView(clip)
            }
        }
    }
}
