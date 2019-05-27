//
//  EditorSplitView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class EditorSplitView: NSSplitView, NSSplitViewDelegate {
    public var shouldHideDivider = false

    override func draw(_ dirtyRect: NSRect) {
        self.delegate = self
        super.draw(dirtyRect)
    }

    override func minPossiblePositionOfDivider(at dividerIndex: Int) -> CGFloat {
        return 0
    }

    /*
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {

        return (shouldHideDivider || UserDefaultsManagement.horizontalOrientation) ? 0 : 200
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {

        return UserDefaultsManagement.horizontalOrientation ? 99999 : 350
    }*/

    override var dividerColor: NSColor {
        if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
            return NSColor.init(named: "divider")!
        } else {
            return NSColor(red:0.83, green:0.83, blue:0.83, alpha:1.0)
        }
    }

    override var dividerThickness: CGFloat {
        get {
            return shouldHideDivider ? 0 : 1
        }
    }

    func splitViewWillResizeSubviews(_ notification: Notification) {
        if let vc = ViewController.shared() {
            vc.editArea.updateTextContainerInset()
        }
    }

}
