//
//  NSTextStorage+.swift
//  FSNotesCore iOS
//
//  Created by Oleksandr Glushchenko on 7/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension NSTextStorage {
    public func updateFont() {
        beginEditing()
        enumerateAttribute(.font, in: NSRange(location: 0, length: self.length)) { (value, range, _) in
            if let font = value as? UIFont {
                var newFont = font.withSize(CGFloat(UserDefaultsManagement.fontSize))

                if #available(iOS 11.0, *), UserDefaultsManagement.dynamicTypeFont {
                    newFont = font.withSize(CGFloat(UserDefaultsManagement.DefaultFontSize))
                    let fontMetrics = UIFontMetrics(forTextStyle: .body)
                    newFont = fontMetrics.scaledFont(for: newFont)
                }

                removeAttribute(.font, range: range)
                addAttribute(.font, value: newFont, range: range)
                fixAttributes(in: range)
            }
        }
        endEditing()
    }
}
