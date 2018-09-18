//
//  UITextView+.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 7/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension UITextView {
    public func applyLeftParagraphStyle() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        paragraphStyle.alignment = .left

        self.typingAttributes[NSAttributedStringKey.paragraphStyle.rawValue] = paragraphStyle
        self.textStorage.updateParagraphStyle()
    }
}
