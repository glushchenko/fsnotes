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
        var symTraits = fontDescriptor.symbolicTraits
        symTraits.insert(.traitItalic)

        return self.buildFont(symTraits: symTraits)
    }
    
    func bold() -> UIFont {
        var symTraits = fontDescriptor.symbolicTraits
        symTraits.insert(.traitBold)

        return self.buildFont(symTraits: symTraits)
    }
    
    func unBold() -> UIFont {
        var symTraits = fontDescriptor.symbolicTraits
        symTraits.remove(.traitBold)
        
        return self.buildFont(symTraits: symTraits)
    }
    
    func unItalic() -> UIFont {
        var symTraits = fontDescriptor.symbolicTraits
        symTraits.remove(.traitItalic)

        return self.buildFont(symTraits: symTraits)
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
