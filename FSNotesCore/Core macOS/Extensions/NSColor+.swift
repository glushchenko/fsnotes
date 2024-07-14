//
//  NSColor+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 11.08.2021.
//  Copyright © 2021 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

public extension NSColor {
    convenience init(hex: String) {
       let trimHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
       let dropHash = String(trimHex.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
       let hexString = trimHex.starts(with: "#") ? dropHash : trimHex
       let ui64 = UInt64(hexString, radix: 16)
       let value = ui64 != nil ? Int(ui64!) : 0
       // #RRGGBB
       var components = (
           R: CGFloat((value >> 16) & 0xff) / 255,
           G: CGFloat((value >> 08) & 0xff) / 255,
           B: CGFloat((value >> 00) & 0xff) / 255,
           a: CGFloat(1)
       )
       if String(hexString).count == 8 {
           // #RRGGBBAA
           components = (
               R: CGFloat((value >> 24) & 0xff) / 255,
               G: CGFloat((value >> 16) & 0xff) / 255,
               B: CGFloat((value >> 08) & 0xff) / 255,
               a: CGFloat((value >> 00) & 0xff) / 255
           )
       }

       self.init(red: components.R, green: components.G, blue: components.B, alpha: components.a)
    }

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
