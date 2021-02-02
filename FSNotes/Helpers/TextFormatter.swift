//
//  TextFormatter.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/6/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
    import Carbon.HIToolbox
    typealias Font = NSFont
    typealias TextView = EditTextView
    typealias Color = NSColor
#else
    import UIKit
    import NightNight
    typealias Font = UIFont
    typealias TextView = EditTextView
    typealias Color = UIColor
#endif

public class TextFormatter {
    private var attributedString: NSMutableAttributedString
    private var attributedSelected: NSAttributedString
    private var type: NoteType
    private var textView: TextView
    private var note: Note
    private var storage: NSTextStorage
    private var selectedRange: NSRange
    private var range: NSRange
    private var newSelectedRange: NSRange?
    private var cursor: Int?
    
    private var prevSelectedString: NSAttributedString
    private var prevSelectedRange: NSRange
    
    private var isAutomaticQuoteSubstitutionEnabled: Bool = false
    private var isAutomaticDashSubstitutionEnabled: Bool = false
    
    private var shouldScanMarkdown: Bool
    
    init(textView: TextView, note: Note, shouldScanMarkdown: Bool = true) {
        range = textView.selectedRange
        
        #if os(OSX)
            storage = textView.textStorage!
            attributedSelected = textView.attributedString()
            if textView.typingAttributes[.font] == nil {
                textView.typingAttributes[.font] = UserDefaultsManagement.noteFont
            }
        #else
            storage = textView.textStorage
            attributedSelected = textView.attributedText
        #endif
        
        self.attributedString = NSMutableAttributedString(attributedString: attributedSelected.attributedSubstring(from: range))
        self.selectedRange = NSRange(0..<attributedString.length)
        
        self.type = note.type
        self.textView = textView
        self.note = note
        
        prevSelectedRange = range
        prevSelectedString = storage.attributedSubstring(from: prevSelectedRange)
        
        #if os(OSX)
            self.isAutomaticQuoteSubstitutionEnabled = textView.isAutomaticQuoteSubstitutionEnabled
            self.isAutomaticDashSubstitutionEnabled = textView.isAutomaticDashSubstitutionEnabled
        
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
        #endif
        
        self.shouldScanMarkdown = note.isMarkdown() ? shouldScanMarkdown : false
    }
    
    func getString() -> NSMutableAttributedString {
        return attributedString
    }
    
    func bold() {
        if note.isMarkdown() {

            // UnBold if not selected
            if range.length == 0 {
                var resultFound = false
                let string = getAttributedString().string

                NotesTextProcessor.boldRegex.matches(string, range: NSRange(0..<string.count)) { (result) -> Void in
                    guard let range = result?.range else { return }

                    if range.intersection(self.range) != nil {
                        let boldAttributed = self.getAttributedString().attributedSubstring(from: range)

                        self.unBold(attributedString: boldAttributed, range: range)
                        resultFound = true
                    }
                }

                if resultFound {
                    return
                }
            }

            // UnBold selected
            if attributedString.string.contains("**") || attributedString.string.contains("__") {
                unBold(attributedString: attributedString, range: range)
                return
            }

            var selectRange = NSMakeRange(range.location + 2, 0)
            let string = attributedString.string
            let length = string.count

            if length != 0 {
                selectRange = NSMakeRange(range.location, length + 4)
            }

            insertText("**" + string + "**", selectRange: selectRange)
        }
        
        if type == .RichText {
            let newFont = toggleBoldFont(font: getTypingAttributes())
            
            #if os(iOS)
            guard self.attributedString.length > 0 else {
                self.setTypingAttributes(font: newFont)
                return
            }
            #endif
            
            textView.undoManager?.beginUndoGrouping()

            #if os(OSX)
                let string = NSMutableAttributedString(attributedString: attributedString)
                string.addAttribute(.font, value: newFont, range: selectedRange)
                self.insertText(string, replacementRange: range, selectRange: range)
                setTypingAttributes(font: newFont)
            #else
                let selectedRange = textView.selectedRange
                let selectedTextRange = textView.selectedTextRange!
                let selectedText = textView.textStorage.attributedSubstring(from: selectedRange)
            
                let mutableAttributedString = NSMutableAttributedString(attributedString: selectedText)
                mutableAttributedString.toggleBoldFont()
            
                textView.replace(selectedTextRange, withText: selectedText.string)
                textView.textStorage.replaceCharacters(in: selectedRange, with: mutableAttributedString)
                textView.selectedRange = selectedRange
            #endif

            textView.undoManager?.endUndoGrouping()
        }
    }
    
    func italic() {
        if note.isMarkdown() {

            // UnItalic if not selected
            if range.length == 0 {
                var resultFound = false
                let string = getAttributedString().string

                NotesTextProcessor.italicRegex.matches(string, range: NSRange(0..<string.count)) { (result) -> Void in
                    guard let range = result?.range else { return }

                    if range.intersection(self.range) != nil {
                        let italicAttributed = self.getAttributedString().attributedSubstring(from: range)

                        self.unItalic(attributedString: italicAttributed, range: range)
                        resultFound = true
                    }
                }

                if resultFound {
                    return
                }
            }

            // UnItalic
            if attributedString.string.contains("*") || attributedString.string.contains("_") {
                unItalic(attributedString: attributedString, range: range)
                return
            }

            var selectRange = NSMakeRange(range.location + 1, 0)
            let string = attributedString.string
            let length = string.count

            if length != 0 {
                selectRange = NSMakeRange(range.location, length + 2)
            }

            insertText("_" + string + "_", selectRange: selectRange)
        }
        
        if type == .RichText {
            let newFont = toggleItalicFont(font: getTypingAttributes())
            
            #if os(iOS)
            guard attributedString.length > 0 else {
                setTypingAttributes(font: newFont)
                return
            }
            #endif
            
            textView.undoManager?.beginUndoGrouping()
            #if os(OSX)
                let string = NSMutableAttributedString(attributedString: attributedString)
                string.addAttribute(.font, value: newFont, range: selectedRange)
                self.insertText(string, replacementRange: range, selectRange: range)
                setTypingAttributes(font: newFont)
            #else
                let selectedRange = textView.selectedRange
                let selectedTextRange = textView.selectedTextRange!
                let selectedText = textView.textStorage.attributedSubstring(from: selectedRange)
            
                let mutableAttributedString = NSMutableAttributedString(attributedString: selectedText)
                mutableAttributedString.toggleItalicFont()
            
                textView.replace(selectedTextRange, withText: selectedText.string)
                textView.textStorage.replaceCharacters(in: selectedRange, with: mutableAttributedString)
                textView.selectedRange = selectedRange
            #endif
            textView.undoManager?.endUndoGrouping()
        }
    }

    private func unBold(attributedString: NSAttributedString, range: NSRange) {
        let unBold = attributedString
            .string
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")

        let selectRange = NSRange(location: range.location, length: unBold.count)
        insertText(unBold, replacementRange: range, selectRange: selectRange)
    }

    private func unItalic(attributedString: NSAttributedString, range: NSRange) {
        let unItalic = attributedString
            .string
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")

        let selectRange = NSRange(location: range.location, length: unItalic.count)
        insertText(unItalic, replacementRange: range, selectRange: selectRange)
    }

    private func unStrike(attributedString: NSAttributedString, range: NSRange) {
        let unStrike = attributedString
            .string
            .replacingOccurrences(of: "~~", with: "")

        let selectRange = NSRange(location: range.location, length: unStrike.count)
        insertText(unStrike, replacementRange: range, selectRange: selectRange)
    }
    
    public func underline() {
        if note.type == .RichText {
            if (attributedString.length > 0) {
                #if os(iOS)
                    let selectedtTextRange = textView.selectedTextRange!
                #endif

                let selectedRange = textView.selectedRange
                let range = NSRange(0..<attributedString.length)

                if let underline = attributedString.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int {
                    if underline == 1 {
                        attributedString.removeAttribute(.underlineStyle, range: range)
                    } else {
                        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                        attributedString.addAttribute(.underlineColor, value: NotesTextProcessor.underlineColor, range: range)
                    }
                } else {
                    attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                    attributedString.addAttribute(.underlineColor, value: NotesTextProcessor.underlineColor, range: range)
                }

                #if os(iOS)
                    self.textView.replace(selectedtTextRange, withText: attributedString.string)
                    self.textView.selectedRange = selectedRange
                #endif

                self.textView.undoManager?.beginUndoGrouping()
                self.storage.replaceCharacters(in: selectedRange, with: attributedString)
                self.textView.undoManager?.endUndoGrouping()

                self.textView.selectedRange = selectedRange
                return
            }
            
            #if os(OSX)
                if (textView.typingAttributes[.underlineStyle] == nil) {
                    attributedString.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)


                    attributedString.addAttribute(.underlineColor, value: NotesTextProcessor.underlineColor, range: selectedRange)

                    
                    textView.typingAttributes[.underlineStyle] = 1
                } else {
                    textView.typingAttributes.removeValue(forKey: NSAttributedString.Key(rawValue: "NSUnderline"))
                }

                textView.insertText(attributedString, replacementRange: textView.selectedRange)
            #else
            if (textView.typingAttributes[.underlineStyle] == nil) {
                textView.typingAttributes[.underlineStyle] = 1
                } else {
                    textView.typingAttributes.removeValue(forKey: .underlineStyle)
                }
            #endif
        }
    }
    
    public func strike() {
        if note.type == .RichText {
            if (attributedString.length > 0) {
                #if os(iOS)
                    let selectedtTextRange = textView.selectedTextRange!
                #endif

                let selectedRange = textView.selectedRange
                let range = NSRange(0..<attributedString.length)

                if let underline = attributedString.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int {
                    if underline == 2 {
                        attributedString.removeAttribute(.strikethroughStyle, range: range)
                    } else {
                        attributedString.addAttribute(.strikethroughStyle, value: 2, range: range)
                    }
                } else {
                    attributedString.addAttribute(.strikethroughStyle, value: 2, range: range)
                }

                #if os(iOS)
                    self.textView.replace(selectedtTextRange, withText: attributedString.string)
                #endif

                self.textView.undoManager?.beginUndoGrouping()
                self.storage.replaceCharacters(in: selectedRange, with: attributedString)
                self.textView.undoManager?.endUndoGrouping()

                self.textView.selectedRange = selectedRange
                return
            }
            
            #if os(OSX)
                if (textView.typingAttributes[.strikethroughStyle] == nil) {
                    attributedString.addAttribute(NSAttributedString.Key.strikethroughStyle, value: 2, range: selectedRange)
                    textView.typingAttributes[.strikethroughStyle] = 2
                } else {
                    textView.typingAttributes.removeValue(forKey: NSAttributedString.Key(rawValue: "NSStrikethrough"))
                }
            
                textView.insertText(attributedString, replacementRange: textView.selectedRange)
            #else
                if (textView.typingAttributes[.strikethroughStyle] == nil) {
                    textView.typingAttributes[.strikethroughStyle] = 2
                } else {
                    textView.typingAttributes.removeValue(forKey: .strikethroughStyle)
                }
            #endif
        }
        
        if note.isMarkdown() {

            // UnStrike if not selected
            if range.length == 0 {
                var resultFound = false
                let string = getAttributedString().string

                NotesTextProcessor.strikeRegex.matches(string, range: NSRange(0..<string.count)) { (result) -> Void in
                    guard let range = result?.range else { return }

                    if range.intersection(self.range) != nil {
                        let italicAttributed = self.getAttributedString().attributedSubstring(from: range)

                        self.unStrike(attributedString: italicAttributed, range: range)
                        resultFound = true
                    }
                }

                if resultFound {
                    return
                }
            }

            // UnStrike
            if attributedString.string.contains("~~") {
                unStrike(attributedString: attributedString, range: range)
                return
            }

            var selectRange = NSMakeRange(range.location + 2, 0)
            let string = attributedString.string
            let length = string.count

            if length != 0 {
                selectRange = NSMakeRange(range.location, length + 4)
            }

            insertText("~~" + string + "~~", selectRange: selectRange)
        }
    }
    
    public func tab() {
        guard let pRange = getParagraphRange() else { return }
        let padding = UserDefaultsManagement.spacesInsteadTabs ? "    " : "\t"

        let string = getAttributedString().attributedSubstring(from: pRange).string
        var result = String()
        var lineQty = 0

        string.enumerateLines { (line, _) in
            result.append(padding + line + "\n")
            lineQty += 1
        }

        let selectRange = textView.selectedRange.length == 0 || lineQty == 1
            ? NSRange(location: pRange.location + result.count - 1, length: 0)
            : NSRange(location: pRange.location, length: result.count)

        insertText(result, replacementRange: pRange, selectRange: selectRange)
    }
    
    public func unTab() {
        guard let pRange = getParagraphRange() else { return }

        let string = storage.attributedSubstring(from: pRange).string
        var result = String()
        var lineQty = 0

        string.enumerateLines { (line, _) in
            var line = line

            if !line.isEmpty {
                if line.first == "\t" {
                    line = String(line.dropFirst())
                } else if line.starts(with: "    ") {
                    line = String(line.dropFirst(4))
                }
            }
            
            result.append(line + "\n")
            lineQty += 1
        }

        let selectRange = textView.selectedRange.length == 0 || lineQty == 1
            ? NSRange(location: pRange.location + result.count - 1, length: 0)
            : NSRange(location: pRange.location, length: result.count)

        insertText(result, replacementRange: pRange, selectRange: selectRange)
    }
    
    public func header(_ string: String) {
        guard let pRange = getParagraphRange() else { return }

#if os(iOS)
        var prefix = String()
        var paragraph = storage.mutableString.substring(with: pRange)

        if paragraph.starts(with: "######") {
            paragraph = paragraph
                .replacingOccurrences(of: "#", with: "")
                .trim()
        } else if paragraph.starts(with: "#") {
            prefix = string
        } else {
            prefix = string + " "
        }

        let diff = paragraph.contains("\n") ? 1 : 0
        let selectRange = NSRange(location: pRange.location + (prefix + paragraph).count - diff, length: 0)
        insertText(prefix + paragraph, replacementRange: pRange, selectRange: selectRange)
#else
        let prefix = string + " "
        var paragraph = storage.mutableString
            .substring(with: pRange)

        if paragraph.starts(with: prefix) {
            paragraph = paragraph.replacingOccurrences(of: prefix, with: "")
        } else {
            paragraph =
                prefix + paragraph.replacingOccurrences(of: "#", with: "").trim()
        }

        let diff = paragraph.contains("\n") ? 1 : 0
        let selectRange = NSRange(location: pRange.location + paragraph.count - diff, length: 0)
        insertText(paragraph, replacementRange: pRange, selectRange: selectRange)
#endif
    }
    
    public func link() {
        let text = "[" + attributedString.string + "]()"
        replaceWith(string: text, range: range)
        
        if (attributedString.length == 4) {
            setSelectedRange(NSMakeRange(range.location + 1, 0))
        } else {
            setSelectedRange(NSMakeRange(range.upperBound + 3, 0))
        }
    }

#if os(OSX)
    public func wikiLink() {
        let text = "[[" + attributedString.string + "]]"
        replaceWith(string: text, range: range)

        if (text.count == 4) {
            setSelectedRange(NSMakeRange(range.location + 2, 0))
            textView.complete(nil)
        } else {
            setSelectedRange(NSMakeRange(range.location + 2, text.count - 4))
        }
    }
#endif

    public func image() {
        let text = "![" + attributedString.string + "]()"
        replaceWith(string: text)
        
        if (attributedString.length == 5) {
            setSelectedRange(NSMakeRange(range.location + 2, 0))
        } else {
            setSelectedRange(NSMakeRange(range.upperBound + 4, 0))
        }
    }

    public func tabKey() {
        guard let currentPR = getParagraphRange() else { return }
        let paragraph = storage.attributedSubstring(from: currentPR).string
        let sRange = self.textView.selectedRange
        
        // Middle
        if (sRange.location != 0 || sRange.location != storage.length)
            && paragraph.count == 1
            && self.note.isMarkdown()
        {
            self.insertText("\t", replacementRange: sRange)
            return
        }
        
        // First & Last
        if (sRange.location == 0 || sRange.location == self.storage.length) && paragraph.count == 0 && self.note.isMarkdown() {
            #if os(OSX)
            if textView.textStorage?.length == 0 {
                EditTextView.shouldForceRescan = true
            }
            #else
            if textView.textStorage.length == 0 {
                EditTextView.shouldForceRescan = true
            }
            #endif
            
            self.insertText("\t\n", replacementRange: sRange)
            self.setSelectedRange(NSRange(location: sRange.location + 1, length: 0))
            return
        }
        
        self.insertText("\t")
    }

    public static func getAutocompleteCharsMatch(string: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern:
            "^(( |\t)*\\- \\[[x| ]*\\] )|^(( |\t)*[-|–|—|*|•|>|\\+]{1} )"), let result = regex.firstMatch(in: string, range: NSRange(0..<string.count)) else { return nil }

        return result
    }

    public static func getAutocompleteDigitsMatch(string: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: "^(( |\t)*[0-9]+\\. )"), let result = regex.firstMatch(in: string, range: NSRange(0..<string.count)) else { return nil }

        return result
    }

    private func matchChars(string: NSAttributedString, match: NSTextCheckingResult, prefix: String? = nil) {
        guard string.length >= match.range.upperBound else { return }

        let found = string.attributedSubstring(from: match.range).string
        var newLine = 1

        if textView.selectedRange.upperBound == storage.length {
            newLine = 0
        }

        if found.count + newLine == string.length {
            let range = storage.mutableString.paragraphRange(for: textView.selectedRange)
            let selectRange = NSRange(location: range.location, length: 0)
            insertText("\n", replacementRange: range, selectRange: selectRange)
            return
        }

        insertText("\n" + found)
    }

    private func matchDigits(string: NSAttributedString, match: NSTextCheckingResult) {
        guard string.length >= match.range.upperBound else { return }

        let found = string.attributedSubstring(from: match.range).string
        var newLine = 1

        if textView.selectedRange.upperBound == storage.length {
            newLine = 0
        }

        if found.count + newLine == string.length {
            let range = storage.mutableString.paragraphRange(for: textView.selectedRange)
            let selectRange = NSRange(location: range.location, length: 0)
            insertText("\n", replacementRange: range, selectRange: selectRange)
            return
        }

        if let position = Int(found.replacingOccurrences(of:"[^0-9]", with: "", options: .regularExpression)) {
            let newDigit = found.replacingOccurrences(of: String(position), with: String(position + 1))
            insertText("\n" + newDigit)
        }
    }

    public func newLine() {
        guard let currentParagraphRange = self.getParagraphRange() else { return }

        let currentParagraph = storage.attributedSubstring(from: currentParagraphRange)
        let selectedRange = self.textView.selectedRange

        // Autocomplete todo lists

        if selectedRange.location != currentParagraphRange.location && currentParagraphRange.upperBound - 2 < selectedRange.location, currentParagraph.length >= 2 {

            if textView.selectedRange.upperBound > 2 {
                let char = storage.attributedSubstring(from: NSRange(location: textView.selectedRange.upperBound - 2, length: 1))

                if let _ = char.attribute(.todo, at: 0, effectiveRange: nil) {
                    let selectRange = NSRange(location: currentParagraphRange.location, length: 0)
                    insertText("\n", replacementRange: currentParagraphRange, selectRange: selectRange)
                    return
                }
            }

            var todoLocation = -1
            currentParagraph.enumerateAttribute(.todo, in: NSRange(0..<currentParagraph.length), options: []) { (value, range, stop) -> Void in
                guard value != nil else { return }

                todoLocation = range.location
                stop.pointee = true
            }

            if todoLocation > -1 {
                let unchecked = AttributedBox.getUnChecked()?.attributedSubstring(from: NSRange(0..<2))
                var prefix = String()

                if todoLocation > 0 {
                    prefix = currentParagraph.attributedSubstring(from: NSRange(0..<todoLocation)).string
                }

            #if os(OSX)
                let string = NSMutableAttributedString(string: "\n" + prefix)
                string.append(unchecked!)
                self.insertText(string)
            #else
                let selectedRange = textView.selectedRange
                let selectedTextRange = textView.selectedTextRange!
                let checkbox = NSMutableAttributedString(string: "\n" + prefix)
                checkbox.append(unchecked!)

                textView.undoManager?.beginUndoGrouping()
                textView.replace(selectedTextRange, withText: checkbox.string)
                textView.textStorage.replaceCharacters(in: NSRange(location: selectedRange.location, length: checkbox.length), with: checkbox)
                textView.undoManager?.endUndoGrouping()
            #endif
                return
            }
        }

        // Autocomplete ordered and unordered lists

        if selectedRange.location != currentParagraphRange.location && currentParagraphRange.upperBound - 2 < selectedRange.location {
            if let charsMatch = TextFormatter.getAutocompleteCharsMatch(string: currentParagraph.string) {
                self.matchChars(string: currentParagraph, match: charsMatch)
                return
            }

            if let digitsMatch = TextFormatter.getAutocompleteDigitsMatch(string: currentParagraph.string) {
                self.matchDigits(string: currentParagraph, match: digitsMatch)
                return
            }
        }

        // New Line insertion

        var newLine = "\n"

        if currentParagraph.string.starts(with: "\t"), let prefix = currentParagraph.string.getPrefixMatchSequentially(char: "\t") {
            if selectedRange.location != currentParagraphRange.location {
                newLine += prefix
            }

            let string = TextFormatter.getAttributedCode(string: newLine)
            self.insertText(string)
            return
        }

        if currentParagraph.string.starts(with: "    "),
            let prefix = currentParagraph.string.getPrefixMatchSequentially(char: " ") {
            if selectedRange.location != currentParagraphRange.location {
                newLine += prefix
            }

            let string = TextFormatter.getAttributedCode(string: newLine)
            self.insertText(string)
            return
        }

        #if os(iOS)
            self.textView.insertText("\n")
        #else
            self.textView.insertNewline(nil)
        #endif
    }

    public func todo() {
        guard let pRange = getParagraphRange() else { return }

        let attributedString = getAttributedString().attributedSubstring(from: pRange)
        let mutable = NSMutableAttributedString(attributedString: attributedString).unLoadCheckboxes()

        if !attributedString.hasTodoAttribute() && selectedRange.length == 0 {
            insertText(AttributedBox.getUnChecked()!)
            return
        }

        var lines = [String]()
        var addPrefixes = false
        var addCompleted = false
        let string = mutable.string

        string.enumerateLines { (line, _) in
            let result = self.parseTodo(line: line)
            addPrefixes = !result.0
            addCompleted = result.1
            lines.append(result.2)
        }

        var result = String()
        for line in lines {
            if addPrefixes {
                let task = addCompleted ? "- [x] " : "- [ ] "
                var empty = String()
                var scanFinished = false

                if line.count > 0 {
                    for char in line {
                        if char.isWhitespace && !scanFinished {
                            empty.append(char)
                        } else {
                            if !scanFinished {
                                empty.append(task + "\(char)")
                                scanFinished = true
                            } else {
                                empty.append(char)
                            }
                        }
                    }

                    result += empty + "\n"
                } else {
                    result += task + "\n"
                }
            } else {
                result += line + "\n"
            }
        }

        let mutableResult = NSMutableAttributedString(string: result)

#if os(iOS)
        let textColor: UIColor = NightNight.theme == .night ? UIColor.white : UIColor.black
        mutableResult.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: mutableResult.length))
        mutableResult.addAttribute(.font, value: NotesTextProcessor.font, range: NSRange(location: 0, length: mutableResult.length))
#endif

        mutableResult.loadCheckboxes()

        let diff = mutableResult.length - attributedString.length
        let selectRange = selectedRange.length == 0 || lines.count == 1
            ? NSRange(location: pRange.location + pRange.length + diff - 1, length: 0)
            : NSRange(location: pRange.location, length: mutableResult.length)

        insertText(mutableResult, replacementRange: pRange, selectRange: selectRange)
    }

    public func toggleTodo(_ location: Int? = nil) {
        if let location = location, let todoAttr = storage.attribute(.todo, at: location, effectiveRange: nil) as? Int {
            let attributedText = (todoAttr == 0) ? AttributedBox.getChecked() : AttributedBox.getUnChecked()

            self.textView.undoManager?.beginUndoGrouping()
            self.storage.replaceCharacters(in: NSRange(location: location, length: 1), with: (attributedText?.attributedSubstring(from: NSRange(0..<1)))!)
            self.textView.undoManager?.endUndoGrouping()

            guard let paragraph = getParagraphRange(for: location) else { return }
            
            if todoAttr == 0 {
                self.storage.addAttribute(.strikethroughStyle, value: 1, range: paragraph)
            } else {
                self.storage.removeAttribute(.strikethroughStyle, range: paragraph)
            }
            
            if paragraph.contains(location) {
                let strike = (todoAttr == 0) ? 1 : 0
                #if os(OSX)
                    textView.typingAttributes[.strikethroughStyle] = strike
                #else
                    textView.typingAttributes[.strikethroughStyle] = strike
                #endif
            }
            
            return
        }

        guard var paragraphRange = getParagraphRange() else { return }

        if let location = location {
            let string = self.storage.string as NSString
            paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
        } else {
            guard let attributedText = AttributedBox.getUnChecked() else { return }


            // Toggle render if exist in current paragraph
            var rangeFound = false
            let attributedParagraph = self.storage.attributedSubstring(from: paragraphRange)
            attributedParagraph.enumerateAttribute(.todo, in: NSRange(0..<attributedParagraph.length), options: []) { value, range, stop in

                if let value = value as? Int {
                    let attributedText = (value == 0) ? AttributedBox.getCleanChecked() : AttributedBox.getCleanUnchecked()
                    let existsRange = NSRange(location: paragraphRange.lowerBound + range.location, length: 1)

                    self.textView.undoManager?.beginUndoGrouping()
                    self.storage.replaceCharacters(in: existsRange, with: attributedText)
                    self.textView.undoManager?.endUndoGrouping()

                    stop.pointee = true
                    rangeFound = true
                }
            }

            guard !rangeFound else { return }

#if os(iOS)
            if let selTextRange = self.textView.selectedTextRange {
                let newRange = NSRange(location: self.textView.selectedRange.location, length: attributedText.length)
                self.textView.undoManager?.beginUndoGrouping()
                self.textView.replace(selTextRange, withText: attributedText.string)
                self.storage.replaceCharacters(in: newRange, with: attributedText)
                self.textView.undoManager?.endUndoGrouping()
            }
#else
            self.insertText(attributedText)
#endif
            return
        }
        
        let paragraph = self.storage.attributedSubstring(from: paragraphRange)
        
        if let index = paragraph.string.range(of: "- [ ]") {
            let local = paragraph.string.nsRange(from: index).location
            let range = NSMakeRange(paragraphRange.location + local, 5)
            if let attributedText = AttributedBox.getChecked() {
                self.insertText(attributedText, replacementRange: range)
            }
            
            return

        } else if let index = paragraph.string.range(of: "- [x]") {
            let local = paragraph.string.nsRange(from: index).location
            let range = NSMakeRange(paragraphRange.location + local, 5)
            if let attributedText = AttributedBox.getUnChecked() {
                self.insertText(attributedText, replacementRange: range)
            }
            
            return
        }
    }

    public func backTick() {
        let selectedRange = textView.selectedRange

        if selectedRange.length > 0 {
            let text = storage.attributedSubstring(from: selectedRange).string
            let string = "`\(text)`"

            if let codeFont = UserDefaultsManagement.codeFont {
                let mutableString = NSMutableAttributedString(string: string)
                mutableString.addAttribute(.font, value: codeFont, range: NSRange(0..<string.count))

                EditTextView.shouldForceRescan = true
                insertText(mutableString, replacementRange: selectedRange)
                return
            }
        }

        insertText("``")
        setSelectedRange(NSRange(location: selectedRange.location, length: selectedRange.length + 1))
    }

    public func codeBlock() {
        EditTextView.shouldForceRescan = true

        let currentRange = textView.selectedRange
        if currentRange.length > 0 {
            let substring = storage.attributedSubstring(from: currentRange)
            let mutable = NSMutableAttributedString(string: "```\n")
            mutable.append(substring)

            if substring.string.last != "\n" {
                mutable.append(NSAttributedString(string: "\n"))
            }
            
            mutable.append(NSAttributedString(string: "```\n"))

            insertText(mutable.string, replacementRange: currentRange)
            setSelectedRange(NSRange(location: currentRange.location + 3, length: 0))
            return
        }

        insertText("```\n\n```\n")
        setSelectedRange(NSRange(location: currentRange.location + 4, length: 0))
    }

    public func quote() {
        EditTextView.shouldForceRescan = true

        guard let pRange = getParagraphRange() else { return }
        let paragraph = storage.mutableString.substring(with: pRange)

        guard paragraph.isContainsLetters else {
            insertText("> ")
            return
        }

        var hasPrefix = false
        var lines = [String]()

        paragraph.enumerateLines { (line, _) in
            hasPrefix = line.starts(with: "> ")

            var skipNext = false
            var scanFinished = false
            var cleanLine = String()

            for char in line {
                if skipNext {
                    skipNext = false
                    continue
                }

                if char == ">" && !scanFinished {
                    skipNext = true
                    scanFinished = true
                } else {
                    cleanLine.append(char)
                }
            }

            lines.append(cleanLine)
        }

        var result = String()
        for line in lines {
            if hasPrefix {
                result += line + "\n"
            } else {
                result += "> " + line + "\n"
            }
        }

        let selectRange = selectedRange.length == 0 || lines.count == 1
            ? NSRange(location: pRange.location + result.count - 1, length: 0)
            : NSRange(location: pRange.location, length: result.count)

        insertText(result, replacementRange: pRange, selectRange: selectRange)
    }
    
    private func getAttributedTodoString(_ string: String) -> NSAttributedString {
        let string = NSMutableAttributedString(string: string)
        string.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: NSRange(0..<1))

        var color = Color.black
        #if os(OSX)
        if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
            color = NSColor(named: "mainText")!
        }
        #endif

        string.addAttribute(.foregroundColor, value: color, range: NSRange(1..<string.length))
        return string
    }
    
    private func replaceWith(string: String, range: NSRange? = nil) {
        #if os(iOS)
            var selectedRange: UITextRange
        
            if let range = range,
                let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                let end = textView.position(from: start, offset: range.length),
                let sRange = textView.textRange(from: start, to: end) {
                selectedRange = sRange
            } else {
                selectedRange = textView.selectedTextRange!
            }
        
            textView.undoManager?.beginUndoGrouping()
            textView.replace(selectedRange, withText: string)
            textView.undoManager?.endUndoGrouping()
        #else
            var r = textView.selectedRange
            if let range = range {
                r = range
            }
        
            textView.insertText(string, replacementRange: r)
        #endif
    }
    
    deinit {
        #if os(OSX)
            textView.isAutomaticQuoteSubstitutionEnabled = self.isAutomaticQuoteSubstitutionEnabled
            textView.isAutomaticDashSubstitutionEnabled = self.isAutomaticDashSubstitutionEnabled
        #endif
        
        if note.isMarkdown() {
            if var font = UserDefaultsManagement.noteFont {
                #if os(iOS)
                if #available(iOS 11.0, *), UserDefaultsManagement.dynamicTypeFont {
                    let fontMetrics = UIFontMetrics(forTextStyle: .body)
                    font = fontMetrics.scaledFont(for: font)
                }
                #endif
                
                setTypingAttributes(font: font)
            }
        }
        
        if self.shouldScanMarkdown, let paragraphRange = getParagraphRange() {
            NotesTextProcessor.highlightMarkdown(attributedString: storage, paragraphRange: paragraphRange, note: note)
        }
        
        if note.isMarkdown() || note.type == .RichText {
            var text: NSAttributedString?
            
            #if os(OSX)
                text = textView.attributedString()
            #else
                text = textView.attributedText
            #endif
            
            if let attributed = text {
                note.save(attributed: attributed)
            }
        }
        
        #if os(iOS)
            textView.initUndoRedoButons()
        #endif
    }
    
    func getParagraphRange() -> NSRange? {
        if range.upperBound <= storage.length {
            let paragraph = storage.mutableString.paragraphRange(for: range)
            return paragraph
        }
        
        return nil
    }
    
    private func getParagraphRange(for location: Int) -> NSRange? {
        guard location <= storage.length else { return nil}

        let range = NSRange(location: location, length: 0)
        let paragraphRange = storage.mutableString.paragraphRange(for: range)
        
        return paragraphRange
    }
    
    func toggleBoldFont(font: Font) -> Font {
        if (font.isBold) {
            return font.unBold()
        } else {
            return font.bold()
        }
    }
    
    func toggleItalicFont(font: Font) -> Font {
        if (font.isItalic) {
            return font.unItalic()
        } else {
            return font.italic()
        }
    }
    
    func getTypingAttributes() -> Font {
        #if os(OSX)
            return textView.typingAttributes[.font] as! Font
        #else
            if let typingFont = textView.typingFont {
                textView.typingFont = nil
                return typingFont
            }

            guard textView.textStorage.length > 0, textView.selectedRange.location > 0 else { return self.getDefaultFont() }

            let i = textView.selectedRange.location - 1
            let upper = textView.selectedRange.upperBound
            let substring = textView.attributedText.attributedSubstring(from: NSRange(i..<upper))

            if let prevFont = substring.attribute(.font, at: 0, effectiveRange: nil) as? UIFont {
                return prevFont
            }

            return self.getDefaultFont()
        #endif
    }

    #if os(iOS)
    private func getDefaultFont() -> UIFont {
        var font = UserDefaultsManagement.noteFont!

        if UserDefaultsManagement.dynamicTypeFont {
            let fontMetrics = UIFontMetrics(forTextStyle: .body)
            font = fontMetrics.scaledFont(for: font)
        }

        return font
    }
    #endif

    #if os(OSX)
    private func getDefaultColor() -> NSColor {
        var color = Color.black
        if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
            color = NSColor(named: "mainText")!
        }
        return color
    }
    #endif
    
    func setTypingAttributes(font: Font) {
        #if os(OSX)
            textView.typingAttributes[.font] = font
        #else
            textView.typingFont = font
            textView.typingAttributes[.font] = font
        #endif
    }
        
    public func setSelectedRange(_ range: NSRange) {
        #if os(OSX)
            if range.upperBound <= storage.length {
                textView.setSelectedRange(range)
            }
        #else
            textView.selectedRange = range
        #endif
    }
    
    func getAttributedString() -> NSAttributedString {
        #if os(OSX)
            return textView.attributedString()
        #else
            return textView.attributedText
        #endif
    }
    
    public static func getCodeParagraphStyle() -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        #if os(OSX)
        paragraphStyle.textBlocks = [CodeBlock()]
        #endif

        return paragraphStyle
    }

    private func insertText(_ string: Any, replacementRange: NSRange? = nil, selectRange: NSRange? = nil) {
        let range = replacementRange ?? self.textView.selectedRange
        
    #if os(iOS)
        guard
            let start = textView.position(from: self.textView.beginningOfDocument, offset: range.location),
            let end = textView.position(from: start, offset: range.length),
            let selectedRange = textView.textRange(from: start, to: end)
        else { return }
    
        var replaceString = String()
        if let attributedString = string as? NSAttributedString {
            replaceString = attributedString.string
        }
    
        if let plainString = string as? String {
            replaceString = plainString
        }
    
        self.textView.undoManager?.beginUndoGrouping()
        self.textView.replace(selectedRange, withText: replaceString)

        if let string = string as? NSAttributedString {
            storage.replaceCharacters(in: NSRange(location: range.location, length: replaceString.count), with: string)
        }

        let parRange = NSRange(location: range.location, length: replaceString.count)
        let parStyle = NSMutableParagraphStyle()
        parStyle.alignment = .left
        parStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        self.textView.textStorage.addAttribute(.paragraphStyle, value: parStyle, range: parRange)

        self.textView.undoManager?.endUndoGrouping()
    #else
        textView.insertText(string, replacementRange: range)
    #endif
        
        if let select = selectRange {
            setSelectedRange(select)
        }
    }

    public static func getAttributedCode(string: String) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString(string: string)
        let range = NSRange(0..<attributedString.length)

        attributedString.addAttribute(.font, value: NotesTextProcessor.codeFont, range: range)
        return attributedString
    }

    public func list() {
        guard let pRange = getParagraphRange() else { return }

        let string = getAttributedString().attributedSubstring(from: pRange).string

        guard string.isContainsLetters else {
            insertText("- ")
            return
        }

        var lines = [String]()
        var addPrefixes = false

        string.enumerateLines { (line, _) in
            addPrefixes = !self.hasPrefix(line: line, numbers: false)
            let cleanLine = self.cleanListItem(line: line)
            lines.append(cleanLine)
        }

        var result = String()
        for line in lines {
            if addPrefixes {
                var empty = String()
                var scanFinished = false

                for char in line {
                    if char.isWhitespace && !scanFinished {
                        empty.append(char)
                    } else {
                        if !scanFinished {
                            empty.append("- \(char)")
                            scanFinished = true
                        } else {
                            empty.append(char)
                        }
                    }
                }

                result += empty + "\n"
            } else {
                result += line + "\n"
            }
        }

        let selectRange = selectedRange.length == 0 || lines.count == 1
            ? NSRange(location: pRange.location + result.count - 1, length: 0)
            : NSRange(location: pRange.location, length: result.count)

        insertText(result, replacementRange: pRange, selectRange: selectRange)
    }

    public func orderedList() {
        guard let pRange = getParagraphRange() else { return }

        let string = getAttributedString().attributedSubstring(from: pRange).string

        guard string.isContainsLetters else {
            insertText("1. ")
            return
        }

        var lines = [String]()
        var addPrefixes = false

        string.enumerateLines { (line, _) in
            addPrefixes = !self.hasPrefix(line: line, numbers: true)
            let cleanLine = self.cleanListItem(line: line)
            lines.append(cleanLine)
        }

        var result = String()
        var i = 1
        var deep = 0

        for line in lines {
            if addPrefixes {
                var empty = String()
                var scanFinished = false
                var lineDeep = 0

                for char in line {
                    if char.isWhitespace && !scanFinished {
                        empty.append(char)
                        lineDeep += 1
                    } else {
                        if !scanFinished {

                            // Resets numeration on deeper lvl
                            if lineDeep != deep {
                                i = 1
                                deep = lineDeep
                            }

                            empty.append("\(i). \(char)")
                            scanFinished = true
                        } else {
                            empty.append(char)
                        }
                    }
                }


                result += empty + "\n"
                i += 1
            } else {
                result += line + "\n"
            }
        }

        let selectRange = selectedRange.length == 0 || lines.count == 1
            ? NSRange(location: pRange.location + result.count - 1, length: 0)
            : NSRange(location: pRange.location, length: result.count)

        insertText(result, replacementRange: pRange, selectRange: selectRange)
    }

    private func cleanListItem(line: String) -> String {
        var cleanLine = String()
        var prefixFound = false

        var numberCheck = false
        var spaceCheck = false
        var dotCheck = false

        var skipped = String()

        for char in line {
            if numberCheck {
                if char.isNumber {
                    skipped.append(char)
                    continue
                } else {
                    numberCheck = false
                    dotCheck = true
                }
            }

            if dotCheck {
                if char == "." {
                    skipped.append(char)
                    spaceCheck = true
                } else {
                    cleanLine.append(skipped)
                    cleanLine.append(char)
                    skipped = ""
                }

                dotCheck = false
                continue
            }

            if spaceCheck {
                if char.isWhitespace {
                } else {
                    cleanLine.append(skipped)
                    cleanLine.append(char)
                }

                spaceCheck = false
                skipped = ""
                continue
            }

            if char.isWhitespace && !prefixFound {
                cleanLine.append(char)
            } else if !prefixFound {
                if char.isNumber {
                    numberCheck = true
                    skipped.append(char)
                } else if char == "-" {
                    spaceCheck = true
                    skipped.append(char)
                } else {
                    cleanLine.append(char)
                }
                prefixFound = true
            } else {
                cleanLine.append(char)
            }
        }

        if skipped.count > 0 {
            cleanLine.append(skipped)
        }

        return cleanLine
    }

    private func parseTodo(line: String) -> (Bool, Bool, String) {
        var count = 0
        var hasTodoPrefix = false
        var hasIncompletedTask = false
        var charFound = false
        var whitespacePrefix = String()
        var letterPrefix = String()

        for char in line {
            if char.isWhitespace && !charFound {
                count += 1
                whitespacePrefix.append(char)
                continue
            } else {
                charFound = true
                letterPrefix.append(char)
            }
        }

        if letterPrefix.starts(with: "- [ ] ") {
            hasTodoPrefix = false
            hasIncompletedTask = true
        }

        if letterPrefix.starts(with: "- [x] ") {
            hasTodoPrefix = true
        }

        letterPrefix =
            letterPrefix
                .replacingOccurrences(of: "- [ ] ", with: "")
                .replacingOccurrences(of: "- [x] ", with: "")

        return (hasTodoPrefix, hasIncompletedTask, whitespacePrefix + letterPrefix)
    }

    private func hasPrefix(line: String, numbers: Bool) -> Bool {
        var checkNumberDot = false

        for char in line {
            if checkNumberDot {
                if char == "." {
                    return numbers
                }
            }

            if char.isWhitespace {
                continue
            } else {
                if char.isNumber {
                    checkNumberDot = true
                    continue
                } else if char == "-" {
                    return !numbers
                }
            }
        }

        return false
    }
}
