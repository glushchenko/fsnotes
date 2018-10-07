//
//  EditorScrollView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class EditorScrollView: NSScrollView {

    public var textFinder: NSTextFinder?

    override var isFindBarVisible: Bool {
        set {
            if let clip = self.subviews.first as? NSClipView {
                clip.contentInsets.top = newValue ? 50 : 10

                if newValue, let documentView = self.documentView {
                    documentView.scroll(NSPoint(x: 0, y: -50))

                    self.textFinder?.performAction(NSTextFinder.Action.setSearchString)
                }
            }

            super.isFindBarVisible = newValue
        }
        get {
            return super.isFindBarVisible
        }
    }
}
