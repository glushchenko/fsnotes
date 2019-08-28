//
//  NSTextStorage+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/14/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

#if os(OSX)
import AppKit
#else
import UIKit
#endif

extension NSTextStorage {
    public func replaceCheckboxes() {
        while mutableString.contains("- [ ] ") {
            let range = mutableString.range(of: "- [ ] ")
            if length >= range.upperBound, let unChecked = AttributedBox.getUnChecked() {
                beginEditing()
                replaceCharacters(in: range, with: unChecked)
                endEditing()
            }
        }

        while mutableString.contains("- [x] ") {
            let range = mutableString.range(of: "- [x] ")
            if length >= range.upperBound, let checked = AttributedBox.getChecked() {
                beginEditing()
                replaceCharacters(in: range, with: checked)
                endEditing()
            }
        }
    }
}
