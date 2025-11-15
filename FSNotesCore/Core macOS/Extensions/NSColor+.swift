//
//  NSColor+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 11.08.2021.
//  Copyright © 2021 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

public extension NSColor {
    static var tagColor: NSColor {
        get {
            let accentColor = UserDefaults.standard.value(forKey: "AppleAccentColor")
            if #available(macOS 10.14, *), accentColor != nil {
                return NSColor.controlAccentColor
            }

            if #available(macOS 10.13, *) {
                return NSColor(named: "background_tag")!
            }

            return NSColor.gray
        }
    }

    var hexString: String {
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return "#FFFFFF"
        }
        let red = Int(round(rgbColor.redComponent * 0xFF))
        let green = Int(round(rgbColor.greenComponent * 0xFF))
        let blue = Int(round(rgbColor.blueComponent * 0xFF))
        let hexString = NSString(format: "#%02X%02X%02X", red, green, blue)
        return hexString as String
    }
}
