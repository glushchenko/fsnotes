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
            let string = "**" + attributedString.string + "**"
            let location = string.count == 4 ? range.location + 2 : range.upperBound + 4
            self.insertText(string, selectRange: NSMakeRange(location, 0))
        }
        
        if type == .RichText {
            let newFont = toggleBoldFont(font: self.getTypingAttributes())
            
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
            let string = "_" + attributedString.string + "_"
            let location = string.count == 2 ? range.location + 1 : range.upperBound + 2
            self.insertText(string, selectRange: NSMakeRange(location, 0))
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
                        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue, range: range)
                    }
                } else {
                    attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue, range: range)
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
                    attributedString.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue, range: selectedRange)
                    textView.typingAttributes[.underlineStyle] = 1
                } else {
                    textView.typingAttributes.removeValue(forKey: NSAttributedStringKey(rawValue: "NSUnderline"))
                }

                textView.insertText(attributedString, replacementRange: textView.selectedRange)
            #else
                if (textView.typingAttributes[NSAttributedStringKey.underlineStyle.rawValue] == nil) {
                    textView.typingAttributes[NSAttributedStringKey.underlineStyle.rawValue] = 1
                } else {
                    textView.typingAttributes.removeValue(forKey: NSAttributedStringKey.underlineStyle.rawValue)
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
                    attributedString.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 2, range: selectedRange)
                    textView.typingAttributes[.strikethroughStyle] = 2
                } else {
                    textView.typingAttributes.removeValue(forKey: NSAttributedStringKey(rawValue: "NSStrikethrough"))
                }
            
                textView.insertText(attributedString, replacementRange: textView.selectedRange)
            #else
                if (textView.typingAttributes[NSAttributedStringKey.strikethroughStyle.rawValue] == nil) {
                    textView.typingAttributes[NSAttributedStringKey.strikethroughStyle.rawValue] = 2
                } else {
                    textView.typingAttributes.removeValue(forKey: NSAttributedStringKey.strikethroughStyle.rawValue)
                }
            #endif
        }
        
        if note.isMarkdown() {
            let string = "~~" + attributedString.string + "~~"
            let location = string.count == 4 ? range.location + 2 : range.upperBound + 4
            
            self.replaceWith(string: string)
            setSelectedRange(NSMakeRange(location, 0))
        }
    }
    
    public func tab() {
        guard let pRange = getParagraphRange() else { return }
        
        guard range.length > 0 else {
            let text = storage.attributedSubstring(from: pRange).string
            #if os(OSX)
                let location = textView.selectedRange().location
                textView.insertText("\t" + text, replacementRange: pRange)
                self.setSelectedRange(NSMakeRange(location + 1, 0))
            #else
                replaceWith(string: "\t" + text, range: pRange)
                setSelectedRange(NSMakeRange(range.upperBound + 1, 0))
            #endif
            
            if note.isMarkdown() {
                highlight()
            }
            
            return
        }
        
        let string = storage.attributedSubstring(from: pRange).string
        var lines = [String]()
        string.enumerateLines { (line, _) in
            lines.append("\t" + line)
        }
        
        var result = lines.joined(separator: "\n")
        if pRange.upperBound != storage.length {
           result = result + "\n"
        }
        
        #if os(OSX)
            textView.insertText(result, replacementRange: pRange)
        #else
            replaceWith(string: result)
        #endif
        
        setSelectedRange(NSRange(location: pRange.lowerBound, length: result.count))
        
        if note.isMarkdown() {
            highlight()
        }
    }
    
    func unTab() {
        guard let pRange = getParagraphRange() else { return }
        
        guard range.length > 0 else {
            var text = storage.attributedSubstring(from: pRange).string
            guard text.count > 0, [" ", "\t"].contains(text.removeFirst()) else { return }

            #if os(OSX)
                textView.insertText(text, replacementRange: pRange)
                self.setSelectedRange(NSMakeRange(pRange.lowerBound - 1 + text.count, 0))
            #else
                self.insertText(text, replacementRange: pRange)
                self.setSelectedRange(NSRange(location: range.location - 1, length: 0))
            #endif
        
            if note.isMarkdown() {
                highlight()
            }
            
            return
        }
        
        let string = storage.attributedSubstring(from: pRange).string
        var resultList: [String] = []
        string.enumerateLines { (line, _) in
            var line = line
            if !line.isEmpty && [" ", "\t"].contains(line.first) {
                line.removeFirst()
            }
            
            resultList.append(line)
        }
        
        var result = resultList.joined(separator: "\n")
        if pRange.upperBound != storage.length {
            result = result + "\n"
        }
        
        #if os(OSX)
            textView.insertText(result, replacementRange: pRange)
        #else
            replaceWith(string: result)
        #endif

        let finalRange = NSRange(location: pRange.lowerBound, length: result.count)
        setSelectedRange(finalRange)
        
        if note.isMarkdown() {
            NotesTextProcessor.scanBasicSyntax(note: note, storage: storage, range: finalRange)
            highlight()
        }
    }
    
    public func header(_ string: String) {
        #if os(OSX)
            let prefix = string + " "
            let length = string.count + 1
        #else
            let prefix = string
            let length = 1
        #endif
        
        let select = NSMakeRange(range.location + length, 0)
        self.insertText(prefix, replacementRange: range, selectRange: select)
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
    
    public func image() {
        let text = "![" + attributedString.string + "]()"
        replaceWith(string: text)
        
        if (attributedString.length == 5) {
            setSelectedRange(NSMakeRange(range.location + 2, 0))
        } else {
            setSelectedRange(NSMakeRange(range.upperBound + 4, 0))
        }
    }
    
    func highlight() {
        if let paragraphRange = getParagraphRange(), let codeBlockRange = NotesTextProcessor.getCodeBlockRange(paragraphRange: paragraphRange, content: storage),
            codeBlockRange.upperBound <= storage.length,
            UserDefaultsManagement.codeBlockHighlight {

            NotesTextProcessor.highlightCode(range: codeBlockRange, storage: storage, note: note)
        }
    }
    
    public func deleteKey() {
        let sRange = self.textView.selectedRange
        
        guard sRange.location > 0,
            let pr = self.getParagraphRange(for: sRange.location),
            let currentPR = getParagraphRange(),
            self.note.isMarkdown()
        else { return }
        
        // This is code block and not first position
        
        if isCodeBlock(range: pr) {
            if pr.lowerBound != sRange.location {
                let attributes = TextFormatter.getCodeBlockAttributes()
                storage.addAttributes(attributes, range: currentPR)
            }
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
            let attributes = TextFormatter.getCodeBlockAttributes()
            let attributeRange = NSRange(location: sRange.location, length: 2)
            self.storage.addAttributes(attributes, range: attributeRange)
            return
        }
        
        // First & Last
        if (sRange.location == 0 || sRange.location == self.storage.length) && paragraph.count == 0 && self.note.isMarkdown() {
            let codeStyle = self.addCodeBlockStyle("\t\n")
            self.insertText(codeStyle, replacementRange: sRange)
            
            let attributes = TextFormatter.getCodeBlockAttributes()
            let attributeRange = NSRange(location: sRange.location, length: 2)
            self.storage.addAttributes(attributes, range: attributeRange)
            
            self.setSelectedRange(NSRange(location: sRange.location + 1, length: 0))
            return
        }
        
        if self.isCodeBlock(range: currentPR), note.isMarkdown() {
            self.insertText("\t", replacementRange: sRange)
            
            let attributes = TextFormatter.getCodeBlockAttributes()
            let attributeRange = NSRange(location: sRange.location, length: 1)
            self.storage.addAttributes(attributes, range: attributeRange)
            
            self.setSelectedRange(NSRange(location: sRange.location + 1, length: 0))
            return
        }

        self.insertText("\t")
    }

    public static func getAutocompleteCharsMatch(string: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern:
            "^(( |\t)*\\- \\[[x| ]*\\] )|^(( |\t)*[-|–|—|*|•|\\+]{1} )"), let result = regex.firstMatch(in: string, range: NSRange(0..<string.count)) else { return nil }

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
            insertText("", replacementRange: storage.mutableString.paragraphRange(for: textView.selectedRange))
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
            insertText("", replacementRange: storage.mutableString.paragraphRange(for: textView.selectedRange))
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

        if currentParagraph.length >= 2 {
            if textView.selectedRange.upperBound > 2 {
                let char = storage.attributedSubstring(from: NSRange(location: textView.selectedRange.upperBound - 2, length: 1))

                if let _ = char.attribute(.todo, at: 0, effectiveRange: nil) {
                    insertText("", replacementRange: currentParagraphRange)
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
                storage.updateParagraphStyle()
                return
            }
        }

        // Autocomplete ordered and unordered lists
        
        guard let currentPR = getParagraphRange(for: currentParagraphRange.location) else { return }
        let currentP = storage.attributedSubstring(from: currentPR)

        if let charsMatch = TextFormatter.getAutocompleteCharsMatch(string: currentParagraph.string) {
            self.matchChars(string: currentP, match: charsMatch)
            return
        }

        if let digitsMatch = TextFormatter.getAutocompleteDigitsMatch(string: currentParagraph.string) {
            self.matchDigits(string: currentP, match: digitsMatch)
            return
        }

        // New Line insertion

        if currentParagraph.string.starts(with: "\t"), let prefix = currentParagraph.string.getPrefixMatchSequentially(char: "\t") {
            self.insertText(addCodeBlockStyle("\n" + prefix))
            return
        }

        if currentParagraph.string.starts(with: "    "), let prefix = currentParagraph.string.getPrefixMatchSequentially(char: " ") {
            self.insertText(addCodeBlockStyle("\n" + prefix))
            return
        }

        #if os(iOS)
            self.textView.insertText("\n")
        #else
            self.textView.insertNewline(nil)
        #endif

        // Fenced code block style handler

        if UserDefaultsManagement.codeBlockHighlight, self.note.isMarkdown() {
            if let fencedRange = NotesTextProcessor.getFencedCodeBlock(at: selectedRange.location, string: storage) {
                let attributes = TextFormatter.getCodeBlockAttributes()
                self.storage.addAttributes(attributes, range: fencedRange)
            } else {
                if selectedRange.location + 2 <= storage.length {
                    storage.removeAttribute(.backgroundColor, range: NSRange(location: selectedRange.location + 1, length: 1))
                }
            }
        }
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
                    textView.typingAttributes[NSAttributedStringKey.strikethroughStyle.rawValue] = strike
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
            let attributedText = AttributedBox.getChecked()
            
            self.insertText(attributedText, replacementRange: range)

            return

        } else if let index = paragraph.string.range(of: "- [x]") {
            let local = paragraph.string.nsRange(from: index).location
            let range = NSMakeRange(paragraphRange.location + local, 5)
            let attributedText = AttributedBox.getUnChecked()
            
            self.insertText(attributedText, replacementRange: range)
            
            return
        }
    }
    
    private func getAttributedTodoString(_ string: String) -> NSAttributedString {
        let string = NSMutableAttributedString(string: string)
        string.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: NSRange(0..<1))

        var color = Color.black
        #if os(OSX)
        if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
            color = NSColor(named: NSColor.Name(rawValue: "mainText"))!
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
                if #available(iOS 11.0, *) {
                    let fontMetrics = UIFontMetrics(forTextStyle: .body)
                    font = fontMetrics.scaledFont(for: font)
                }
                #endif
                
                setTypingAttributes(font: font)
            }
        }
        
        if self.shouldScanMarkdown, let paragraphRange = getParagraphRange() {
            NotesTextProcessor.scanMarkdownSyntax(storage, paragraphRange: paragraphRange, note: note)
        }
        
        if note.isMarkdown() || note.type == .RichText {
            var text: NSAttributedString?
            
            #if os(OSX)
                text = textView.attributedString()
            #else
                text = textView.attributedText
            #endif
            
            if let t = text {
                note.content = NSMutableAttributedString(attributedString: t)
                note.save()
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

        if #available(iOS 11.0, *) {
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
            color = NSColor(named: NSColor.Name(rawValue: "mainText"))!
        }
        return color
    }
    #endif
    
    func setTypingAttributes(font: Font) {
        #if os(OSX)
            textView.typingAttributes[.font] = font
        #else
            textView.typingFont = font
            textView.typingAttributes[NSAttributedStringKey.font.rawValue] = font
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
    
    private func addCodeBlockStyle(_ text: String) -> NSMutableAttributedString {
        let attributedText = NSMutableAttributedString(string: text)
        
        guard attributedText.length > 0, self.note.isMarkdown() else { return attributedText }
        
        let range = NSRange(0..<text.count)
        attributedText.addAttributes(TextFormatter.getCodeBlockAttributes(), range: range)
        
        return attributedText
    }
    
    public static func getCodeBlockAttributes() -> [NSAttributedStringKey : Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        
        var attributes: [NSAttributedStringKey : Any] = [
            .paragraphStyle: paragraphStyle
        ]

        if UserDefaultsManagement.codeBlockHighlight {
            attributes[.backgroundColor] = NotesTextProcessor.codeBackground
        }
        
        if let font = NotesTextProcessor.codeFont {
            attributes[.font] = font
        }
        
        return attributes
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
        self.textView.undoManager?.endUndoGrouping()
    #else
        self.textView.insertText(string, replacementRange: range)
    #endif
        
        if let select = selectRange {
            setSelectedRange(select)
        }
    }
    
    private func isCodeBlock(range: NSRange) -> Bool {
        let string = self.storage.attributedSubstring(from: range).string
        
        if string.starts(with: "\t") || string.starts(with: "    ") {
            guard TextFormatter.getAutocompleteCharsMatch(string: string) == nil && TextFormatter.getAutocompleteDigitsMatch(string: string) == nil else {
                return false
            }

            return true
        }
        
        if nil != NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: range, string: self.storage) {
            return true
        }
        
        return false
    }
}
