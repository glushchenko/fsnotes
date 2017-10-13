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
    
    var height:CGFloat {
        let constraintRect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        let boundingBox = "A".boundingRect(with: constraintRect, options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSFontAttributeName: self], context: nil)
        
        return boundingBox.height
    }
}
