//
//  Colors.swift
//  FSNotes
//
//  Created by Александр on 30.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class Colors {
    public static var underlineColor: NSColor {
        if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
            return NSColor(named: "underlineColor")!
        } else {
            return NSColor.black
        }
    }
}
