//
//  ShortcutIdentifier.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/15/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

enum ShortcutIdentifier: String {
    case makeNew
    case search
    case clipboard

    // MARK: - Initializers

    init?(fullType: String) {
        guard let last = fullType.components(separatedBy: ".").last else { return nil }
        self.init(rawValue: last)
    }

    // MARK: - Properties

    var type: String {
        return Bundle.main.bundleIdentifier! + ".\(self.rawValue)"
    }
}
