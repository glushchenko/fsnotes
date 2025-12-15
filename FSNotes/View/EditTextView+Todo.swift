//
//  EditTextView+Todo.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

extension EditTextView {
    func clearCompletedTodos() {
        guard let textStorage = textStorage else { return }
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let text = textStorage.string as NSString
        
        undoManager?.beginUndoGrouping()
        
        var linesToRemove: [NSRange] = []
        textStorage.enumerateAttribute(.todo, in: fullRange, options: []) { value, range, stop in
            if let value = value as? Int, value == 1 {
                let lineRange = text.lineRange(for: range)
                
                if !linesToRemove.contains(where: { $0.intersection(lineRange) != nil }) {
                    linesToRemove.append(lineRange)
                }
            }
        }
        
        for lineRange in linesToRemove.sorted(by: { $0.location > $1.location }) {
            if shouldChangeText(in: lineRange, replacementString: "") {
                textStorage.replaceCharacters(in: lineRange, with: "")
                didChangeText()
            }
        }
        
        undoManager?.endUndoGrouping()
        undoManager?.setActionName("Remove TODO Lines")
    }
}
