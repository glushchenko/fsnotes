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

    private func buildFont(symTraits: UIFontDescriptor.SymbolicTraits?) -> UIFont {
        var font: UIFont

        if let traits = symTraits, let descriptor = fontDescriptor.withSymbolicTraits(traits) {
            font = UIFont(descriptor: descriptor, size: descriptor.pointSize)
        } else {
            font = UserDefaultsManagement.noteFont
            font.withSize(fontDescriptor.pointSize)

            return font
        }

        return font
    }

    static func addItalic(font: UIFont) -> UIFont {
        return font.italic()
    }

    static func addBold(font: UIFont) -> UIFont {
        return font.bold()
    }

    func codeBold() -> UIFont {
        let descriptor = UIFontDescriptor(name: familyName, size: pointSize)

        if let boldDescriptor = descriptor.withSymbolicTraits(.traitBold) {
            return UIFont(descriptor: boldDescriptor, size: pointSize)
        }

        return self
    }

    public func getAttachmentHeight() -> Double {
        return Double(pointSize) + 6
    }
}
