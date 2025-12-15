//
//  EditTextView+MoveLines.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

extension EditTextView {
    func moveSelectedLinesUp() {
        guard let textStorage = textStorage,
              textStorage.length > 0 else { return }
        
        let selectedRange = selectedRange()
        
        let lineRange = textStorage.mutableString.lineRange(for: selectedRange)
        if lineRange.location == 0 {
            NSSound.beep()
            return
        }
        
        let previousLineStart = textStorage.mutableString.lineRange(
            for: NSRange(location: lineRange.location - 1, length: 0)
        ).location
        
        let previousLineRange = NSRange(
            location: previousLineStart,
            length: lineRange.location - previousLineStart
        )
        
        let currentLinesAttr = textStorage.attributedSubstring(from: lineRange)
        let previousLineAttr = textStorage.attributedSubstring(from: previousLineRange)
        
        let offsetInLine = selectedRange.location - lineRange.location
        
        let currentLinesString = currentLinesAttr.string
        let needsNewline = !currentLinesString.hasSuffix("\n")
        
        let newContent = NSMutableAttributedString()
        newContent.append(currentLinesAttr)
        
        if needsNewline {
            let attrs = currentLinesAttr.length > 0
                ? currentLinesAttr.attributes(at: currentLinesAttr.length - 1, effectiveRange: nil)
                : [:]
            newContent.append(NSAttributedString(string: "\n", attributes: attrs))
        }
        
        var previousToAppend = previousLineAttr
        if needsNewline && previousLineAttr.string.hasSuffix("\n") {
            let trimmedPrevious = NSMutableAttributedString(attributedString: previousLineAttr)
            trimmedPrevious.deleteCharacters(in: NSRange(location: trimmedPrevious.length - 1, length: 1))
            previousToAppend = trimmedPrevious
        }
        
        newContent.append(previousToAppend)
        
        let combinedRange = NSRange(
            location: previousLineRange.location,
            length: previousLineRange.length + lineRange.length
        )
        
        if shouldChangeText(in: combinedRange, replacementString: newContent.string) {
            textStorage.replaceCharacters(in: combinedRange, with: newContent)
            didChangeText()
        }
        
        let newSelectionLocation = previousLineRange.location + offsetInLine
        
        setSelectedRange(NSRange(
            location: newSelectionLocation,
            length: selectedRange.length
        ))
        
        scrollRangeToVisible(self.selectedRange())
    }

    func moveSelectedLinesDown() {
        guard let textStorage = textStorage,
              textStorage.length > 0 else { return }
        
        let selectedRange = selectedRange()
        let lineRange = textStorage.mutableString.lineRange(for: selectedRange)
        
        if NSMaxRange(lineRange) >= textStorage.length {
            NSSound.beep()
            return
        }
        
        let nextLineRange = textStorage.mutableString.lineRange(
            for: NSRange(location: NSMaxRange(lineRange), length: 0)
        )
        
        let currentLinesAttr = textStorage.attributedSubstring(from: lineRange)
        let nextLineAttr = textStorage.attributedSubstring(from: nextLineRange)
        
        let offsetInLine = selectedRange.location - lineRange.location
        
        let nextLineString = nextLineAttr.string
        let needsNewline = !nextLineString.hasSuffix("\n")
        
        let newContent = NSMutableAttributedString()
        var nextLineFinalLength = nextLineAttr.length
        
        newContent.append(nextLineAttr)
        
        if needsNewline {
            let attrs = nextLineAttr.length > 0
                ? nextLineAttr.attributes(at: nextLineAttr.length - 1, effectiveRange: nil)
                : [:]
            newContent.append(NSAttributedString(string: "\n", attributes: attrs))
            nextLineFinalLength += 1
        }
        
        var currentToAppend = currentLinesAttr
        if needsNewline && currentLinesAttr.string.hasSuffix("\n") {
            let trimmedCurrent = NSMutableAttributedString(attributedString: currentLinesAttr)
            trimmedCurrent.deleteCharacters(in: NSRange(location: trimmedCurrent.length - 1, length: 1))
            currentToAppend = trimmedCurrent
        }
        
        newContent.append(currentToAppend)
        
        let combinedRange = NSRange(
            location: lineRange.location,
            length: lineRange.length + nextLineRange.length
        )
        
        if shouldChangeText(in: combinedRange, replacementString: newContent.string) {
            textStorage.replaceCharacters(in: combinedRange, with: newContent)
            didChangeText()
        }
        
        let newSelectionLocation = lineRange.location + nextLineFinalLength + offsetInLine
        
        setSelectedRange(NSRange(
            location: newSelectionLocation,
            length: selectedRange.length
        ))
        
        scrollRangeToVisible(self.selectedRange())
    }
}
