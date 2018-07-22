//
//  NSMutableAttributedString+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/21/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension NSMutableAttributedString {
    public func unLoadImages() -> NSMutableAttributedString {
        var offset = 0
        let content = self.mutableCopy() as? NSMutableAttributedString

        self.enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in

            if value != nil {
                let newRange = NSRange(location: range.location + offset, length: range.length)
                let filePathKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.path")
                let titleKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.title")

                guard
                    let path = self.attribute(filePathKey, at: range.location, effectiveRange: nil) as? String,
                    let title = self.attribute(titleKey, at: range.location, effectiveRange: nil) as? String else { return }

                if let pathEncoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    content?.replaceCharacters(in: newRange, with: "![\(title)](\(pathEncoded))")
                    offset += 4 + path.count + title.count
                }
            }
        }

        return content!
    }
}
