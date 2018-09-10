//
//  AttributedBox.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/30/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class AttributedBox {
    public static func getChecked() -> NSMutableAttributedString? {
        let todoKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.todo")

        var editorFont: UIFont?
        if #available(iOS 11.0, *) {
            let fontMetrics = UIFontMetrics(forTextStyle: .body)
            editorFont = fontMetrics.scaledFont(for: UserDefaultsManagement.noteFont)
        } else {
            editorFont = UserDefaultsManagement.noteFont
        }

        var night = ""
        if NightNight.theme == .night {
            night = "_white"
        }

        guard var image = UIImage(named: "checkbox\(night).png"),
            let font = editorFont,
            let height = editorFont?.lineHeight else { return nil }

        if let resized = image.resize(maxWidthHeight: Double(height) + 10) {
            image = resized
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        let mid = font.descender + font.capHeight
        attachment.bounds = CGRect(
            x: 0,
            y: font.descender - image.size.height / 2 + mid + 2,
            width: image.size.width,
            height: image.size.height
        ).integral

        let checkboxText = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
        checkboxText.addAttribute(todoKey, value: 1, range: NSRange(0..<1))
        checkboxText.append(NSAttributedString(string: " "))

        return checkboxText
    }

    public static func getUnChecked() -> NSMutableAttributedString? {
        let todoKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.todo")

        var editorFont: UIFont?
        if #available(iOS 11.0, *) {
            let fontMetrics = UIFontMetrics(forTextStyle: .body)
            editorFont = fontMetrics.scaledFont(for: UserDefaultsManagement.noteFont)
        } else {
            editorFont = UserDefaultsManagement.noteFont
        }

        var night = ""
        if NightNight.theme == .night {
            night = "_white"
        }

        guard var image = UIImage(named: "checkbox_empty\(night).png"),
            let font = editorFont,
            let height = editorFont?.lineHeight else { return nil }

        if let resized = image.resize(maxWidthHeight: Double(height) + 10) {
            image = resized
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        let mid = font.descender + font.capHeight
        attachment.bounds = CGRect(
            x: 0,
            y: font.descender - image.size.height / 2 + mid + 2,
            width: image.size.width,
            height: image.size.height
            ).integral

        let checkboxText = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
        checkboxText.addAttribute(todoKey, value: 0, range: NSRange(0..<1))
        checkboxText.append(NSAttributedString(string: " "))

        return checkboxText
    }
}
