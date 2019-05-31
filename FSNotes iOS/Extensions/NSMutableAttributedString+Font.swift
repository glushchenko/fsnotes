//
//  NSMutableAttributedString+Font.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 6/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension NSMutableAttributedString {
    func bold() {
        beginEditing()
        enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let f = value as? UIFont {
                var traits = f.fontDescriptor.symbolicTraits
                traits.insert(UIFontDescriptor.SymbolicTraits.traitBold)
                
                if let descriptor = f.fontDescriptor.withSymbolicTraits(traits) {
                    let font = UIFont(descriptor: descriptor, size: 0)
                    removeAttribute(.font, range: range)
                    addAttribute(.font, value: font, range: range)
                }
            }
        }
        endEditing()
    }
    
    func unBold() {
        beginEditing()
        enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let f = value as? UIFont {
                var traits = f.fontDescriptor.symbolicTraits
                traits.remove(UIFontDescriptor.SymbolicTraits.traitBold)
                
                if let descriptor = f.fontDescriptor.withSymbolicTraits(traits) {
                    let font = UIFont(descriptor: descriptor, size: 0)
                    removeAttribute(.font, range: range)
                    addAttribute(.font, value: font, range: range)
                }
            }
        }
        endEditing()
    }
    
    func unItalic() {
        beginEditing()
        enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let f = value as? UIFont {
                var traits = f.fontDescriptor.symbolicTraits
                traits.remove(UIFontDescriptor.SymbolicTraits.traitItalic)
                
                if let descriptor = f.fontDescriptor.withSymbolicTraits(traits) {
                    let font = UIFont(descriptor: descriptor, size: 0)
                    removeAttribute(.font, range: range)
                    addAttribute(.font, value: font, range: range)
                }
            }
        }
        endEditing()
    }
    
    func italic() {
        beginEditing()
        enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let f = value as? UIFont {
                var traits = f.fontDescriptor.symbolicTraits
                traits.insert(UIFontDescriptor.SymbolicTraits.traitItalic)
                
                if let descriptor = f.fontDescriptor.withSymbolicTraits(traits) {
                    let font = UIFont(descriptor: descriptor, size: 0)
                    removeAttribute(.font, range: range)
                    addAttribute(.font, value: font, range: range)
                }
            }
        }
        endEditing()
    }
    
    func toggleBoldFont() {
        guard let firstCharFont = attribute(.font, at: 0, longestEffectiveRange: nil, in: NSRange(location: 0, length: self.length)) as? UIFont else { return }
        
        if (firstCharFont.isBold) {
            unBold()
        } else {
            bold()
        }
    }
    
    func toggleItalicFont() {
        guard let firstCharFont = attribute(.font, at: 0, longestEffectiveRange: nil, in: NSRange(location: 0, length: self.length)) as? UIFont else { return }
        
        if (firstCharFont.isItalic) {
            unItalic()
        } else {
            italic()
        }
    }
}
