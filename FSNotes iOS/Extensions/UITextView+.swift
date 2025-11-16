//
//  UITextView+.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 7/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension UITextView {
    var cursorOffset: Int? {
        guard let range = selectedTextRange else { return nil }
        return offset(from: beginningOfDocument, to: range.start)
    }

    var cursorIndex: String.Index? {
        guard
            let location = cursorOffset,
            case let length = text.utf16.count-location
        else { return nil }
        return Range(.init(location: location, length: length), in: text)?.lowerBound
    }

    var cursorDistance: Int? {
        guard let cursorIndex = cursorIndex else { return nil }
        return text.distance(from: text.startIndex, to: cursorIndex)
    }
    
    public func getTextRange() -> UITextRange? {
        if let start = position(from: self.beginningOfDocument, offset: self.selectedRange.location),
        let end = position(from: start, offset: self.selectedRange.length),
        let selectedRange = textRange(from: start, to: end) {
            return selectedRange
        }

        return nil
    }

    public func insertAttributedText(_ attr: NSAttributedString) {
        let range = self.selectedRange

        textStorage.beginEditing()
        undoManager?.beginUndoGrouping()

        let old = textStorage.attributedSubstring(from: range)
        undoManager?.registerUndo(withTarget: self) { target in
            target.replace(range: NSRange(location: range.location, length: attr.length), with: old)
        }
        undoManager?.setActionName("Paste") // подпись для Undo меню

        textStorage.replaceCharacters(in: range, with: attr)
        selectedRange = NSRange(location: range.location + attr.length, length: 0)

        undoManager?.endUndoGrouping()
        textStorage.endEditing()

        delegate?.textViewDidChange?(self)
    }

    private func replace(range: NSRange, with attr: NSAttributedString) {
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: attr)
        selectedRange = NSRange(location: range.location + attr.length, length: 0)
        textStorage.endEditing()
        delegate?.textViewDidChange?(self)
    }
}
