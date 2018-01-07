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
        return fontDescriptor.symbolicTraits.contains(.bold)
    }
    
    var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.italic)
    }
    
    var height:CGFloat {
        let constraintRect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        let boundingBox = "A".boundingRect(with: constraintRect, options: NSString.DrawingOptions.usesLineFragmentOrigin, attributes: [NSAttributedStringKey.font: self], context: nil)
        
        return boundingBox.height
    }
        
    static func italicFont() -> NSFont {
        return NSFontManager().convert(UserDefaultsManagement.noteFont, toHaveTrait: .italicFontMask)
    }
    
    static func boldFont() -> NSFont {
        return NSFontManager().convert(UserDefaultsManagement.noteFont, toHaveTrait: .boldFontMask)
    }
}
