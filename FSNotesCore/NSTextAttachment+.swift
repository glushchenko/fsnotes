//
//  NSTextAttachment+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 10/2/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

#if os(OSX)
import AppKit
#else
import UIKit
#endif

import UniformTypeIdentifiers

extension NSTextAttachment {
    public func isFile() -> Bool {
        #if os(iOS)
            return false
        #endif

        #if os(OSX)
            return (attachmentCell?.cellSize().height == 30)
        #endif
    }
}
