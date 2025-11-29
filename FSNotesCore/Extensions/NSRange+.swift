//
//  NSRange+.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 12.10.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

extension NSRange {
    var upperBound: Int { location + length }
    func intersects(_ other: NSRange) -> Bool {
        return NSIntersectionRange(self, other).length > 0
    }
}
