//
//  NSFont+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/26/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

extension NSFont {
    var isBold: Bool {
        return (fontDescriptor.symbolicTraits == 1026)
    }
    
    var isItalic: Bool {
        return (fontDescriptor.symbolicTraits == 1025)
    }
}
