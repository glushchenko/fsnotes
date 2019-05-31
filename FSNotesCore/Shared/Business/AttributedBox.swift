//
//  AttributedBox.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/30/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

#if os(iOS)
    import UIKit
    import NightNight
#else
    import Cocoa
#endif

class AttributedBox {
    public static func getChecked() -> NSMutableAttributedString? {
        let checkboxText = getCleanChecked()
        checkboxText.append(NSAttributedString(string: " "))

        return checkboxText
    }

    public static func getUnChecked() -> NSMutableAttributedString? {
        let checkboxText = getCleanUnchecked()
        checkboxText.append(NSAttributedString(string: " "))

        return checkboxText
    }

    public static func getCleanUnchecked() -> NSMutableAttributedString {
        let font = NotesTextProcessor.font
        let height = font.lineHeight + 5
        let image = getImage(name: "checkbox_empty")

        let attachment = NSTextAttachment()
        attachment.image = image
        let mid = font.descender + font.capHeight
        attachment.bounds = CGRect(
            x: 0,
            y: font.descender - height / 2 + mid + 2,
            width: height,
            height: height
            ).integral

        let checkboxText = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))

        checkboxText.addAttribute(.todo, value: 0, range: NSRange(0..<1))

        return checkboxText
    }

    public static func getCleanChecked() -> NSMutableAttributedString {
        let font = NotesTextProcessor.font
        let height = font.lineHeight + 5
        let image = getImage(name: "checkbox")

        let attachment = NSTextAttachment()
        attachment.image = image
        let mid = font.descender + font.capHeight
        attachment.bounds = CGRect(
            x: 0,
            y: font.descender - height / 2 + mid + 2,
            width: height,
            height: height
            ).integral

        let checkboxText = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))

        checkboxText.addAttribute(.todo, value: 1, range: NSRange(0..<1))

        return checkboxText
    }

    public static func getImage(name: String) -> Image {
        var name = name

        #if os(OSX)
            if name == "checkbox" {
                name = "checkbox_flipped"
            }
            return NSImage(named: name)!
        #else
            var night = String()

            if NightNight.theme == .night {
                night = "_white"
            }

            return UIImage(named: "\(name)\(night).png")!
        #endif
    }
}
