//
//  NSWindow+.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 10.07.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

extension NSWindow {
    public func setFrameOriginToPositionWindowInCenterOfScreen() {
        if let screenSize = screen?.frame.size {
            let origin = NSPoint(x: (screenSize.width-800)/2, y: (screenSize.height-600)/2)
            self.setFrame(NSRect(origin: origin, size: CGSize(width: 800, height: 600)), display: true)
        }
    }
}
