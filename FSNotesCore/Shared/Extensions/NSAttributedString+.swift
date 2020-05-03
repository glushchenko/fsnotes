//
//  NSAttributedString+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 03.05.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension NSAttributedString {
    public func hasTodoAttribute() -> Bool {
        var found = false
        enumerateAttribute(.todo, in: NSRange(0..<length), options: .init()) { _, _, stop in
            found = true
            stop.pointee = true
        }
        return found
    }
}
