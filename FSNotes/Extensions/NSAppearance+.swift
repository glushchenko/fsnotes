//
//  NSAppearance+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import AppKit.NSAppearance

extension NSAppearance {
    var isDark: Bool {
        if self.name == .vibrantDark { return true }

        guard #available(macOS 10.14, *) else { return false }

        return bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
