//
//  NSView+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/11/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

public extension NSView {
    public var viewBackgroundColor: NSColor? {
        get {
            guard let colorRef = self.layer?.backgroundColor else {
                return nil
            }
            return NSColor(cgColor: colorRef)
        }

        set {
            self.wantsLayer = true
            self.layer?.backgroundColor = newValue?.cgColor
        }
    }
}
