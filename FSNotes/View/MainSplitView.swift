//
//  MainSplitView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/13/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class MainSplitView: NSSplitView, NSSplitViewDelegate {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        self.delegate = self
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 200
    }
    
    func splitViewDidResizeSubviews(_ notification: Notification) {
        let vc = self.window?.contentViewController as! ViewController
        vc.checkSidebarConstraint()
    }
}
