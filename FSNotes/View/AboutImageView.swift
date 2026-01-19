//
//  AboutImage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 08.01.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

class AboutImageView: NSImageView {
    override func mouseEntered(with event: NSEvent) {
        image = NSImage(named: "friend")
    }
    
    override func mouseExited(with event: NSEvent) {
        image = NSImage(named: "modern")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
}
