//
//  UIFont+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/6/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension UIFont {
    var isBold: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitBold)
    }
    
    var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
    
    func italic() -> UIFont {
        if let descriptor = fontDescriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: descriptor, size: 0)
        }
        
        return UserDefaultsManagement.noteFont
    }
    
    func bold() -> UIFont {
        if let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) {
            return UIFont(descriptor: descriptor, size: 0)
        }
        
        return UserDefaultsManagement.noteFont
    }
    
    func unBold() -> UIFont {
        var symTraits = fontDescriptor.symbolicTraits
        symTraits.remove(.traitBold)
        
        if let descriptor = fontDescriptor.withSymbolicTraits(symTraits) {
            return UIFont(descriptor: descriptor, size: 0)
        }
        
        return UserDefaultsManagement.noteFont
    }
    
    func unItalic() -> UIFont {
        var symTraits = fontDescriptor.symbolicTraits
        symTraits.remove(.traitItalic)
        
        if let descriptor = fontDescriptor.withSymbolicTraits(symTraits) {
            return UIFont(descriptor: descriptor, size: 0)
        }
        
        return UserDefaultsManagement.noteFont
    }
    
    public static func bodySize() -> UIFont {
        if #available(iOS 11.0, *) {
            let fontMetrics = UIFontMetrics(forTextStyle: .body)
            let font = fontMetrics.scaledFont(for: UserDefaultsManagement.noteFont)
            
            return font
        }
        
        return UserDefaultsManagement.noteFont
    }
}
