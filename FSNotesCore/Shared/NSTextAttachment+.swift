//
//  NSTextAttachment+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 10/2/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

extension NSTextAttachment {
    func isFile() -> Bool {
        return (attachmentCell?.cellSize().height == 40)
    }
}
