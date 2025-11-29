//
//  NSTextCheckingResult+.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.10.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

extension NSTextCheckingResult {
    func optionalRange(at idx: Int) -> NSRange? {
        let range = self.range(at: idx)
        return range.location != NSNotFound ? range : nil
    }
}
