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
#else
    import UIKit
    typealias Font = UIFont
    typealias TextView = EditTextView
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
    private var maxWidth: CGFloat
    
    private var prevSelectedString: NSAttributedString
    private var prevSelectedRange: NSRange
    
    private var isAutomaticQuoteSubstitutionEnabled: Bool = false
    private var isAutomaticDashSubstitutionEnabled: Bool = false
    
    init(textView: TextView, note: Note) {
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
        
        self.maxWidth = textView.frame.width
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
    }
    
    func getString() -> NSMutableAttributedString {
        return attributedString
    }
    
    func bold() {
        if note.isMarkdown() {
            let string = "**" + attributedString.string + "**"
            let location = string.count == 4 ? range.location + 2 : range.upperBound + 4
            
            self.replaceWith(string: string)
            setSRange(NSMakeRange(location, 0))
        }
        
        if type == .RichText {
            let newFont = toggleBoldFont(font: getTypingAttributes())
            guard attributedString.length > 0 else {
                setTypingAttributes(font: newFont)
                return
            }
            
            textView.undoManager?.beginUndoGrouping()
            #if os(OSX)
                if textView.selectedRange().length > 0 {
                    let string = NSMutableAttributedString(attributedString: attributedString)
                        string.addAttribute(.font, value: newFont, range: selectedRange)
                    textView.insertText(string, replacementRange: textView.selectedRange())
                }
                setTypingAttributes(font: newFont)
            #else
                let selectedRange = textView.selectedRange
                let selectedTextRange = textView.selectedTextRange!
                let selectedText = textView.textStorage.attributedSubstring(from: selectedRange)
            
                let mutableAttributedString = NSMutableAttributedString(attributedString: selectedText)
                mutableAttributedString.toggleBoldFont()
            
                textView.replace(selectedTextRange, withText: selectedText.string)
                textView.textStorage.replaceCharacters(in: selectedRange, with: mutableAttributedString)
            #endif
            textView.undoManager?.endUndoGrouping()
        }
    }
    
    func italic() {
        if note.isMarkdown() {
            let string = "_" + attributedString.string + "_"
            let location = string.count == 2 ? range.location + 1 : range.upperBound + 2
            
            self.replaceWith(string: string)
            setSRange(NSMakeRange(location, 0))
        }
        
        if type == .RichText {
            let newFont = toggleItalicFont(font: getTypingAttributes())
            
            guard attributedString.length > 0 else {
                setTypingAttributes(font: newFont)
                return
            }
            
            textView.undoManager?.beginUndoGrouping()
            #if os(OSX)
                if textView.selectedRange().length > 0 {
                    let string = NSMutableAttributedString(attributedString: attributedString)
                    string.addAttribute(.font, value: newFont, range: selectedRange)
                    textView.insertText(string, replacementRange: textView.selectedRange())
                }
                setTypingAttributes(font: newFont)
            #else
                let selectedRange = textView.selectedRange
                let selectedTextRange = textView.selectedTextRange!
                let selectedText = textView.textStorage.attributedSubstring(from: selectedRange)
            
                let mutableAttributedString = NSMutableAttributedString(attributedString: selectedText)
                mutableAttributedString.toggleItalicFont()
            
                textView.replace(selectedTextRange, withText: selectedText.string)
                textView.textStorage.replaceCharacters(in: selectedRange, with: mutableAttributedString)
            #endif
            textView.undoManager?.endUndoGrouping()
        }
    }
    
    public func underline() {
        if note.type == .RichText {
            if (attributedString.length > 0) {
                attributedString.removeAttribute(NSAttributedStringKey(rawValue: "NSUnderline"), range: selectedRange)
            }
            
            #if os(OSX)
                if (textView.typingAttributes[.underlineStyle] == nil) {
                    attributedString.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue, range: selectedRange)
                    textView.typingAttributes[.underlineStyle] = 1
                } else {
                    textView.typingAttributes.removeValue(forKey: NSAttributedStringKey(rawValue: "NSUnderline"))
                }
            
                textView.insertText(attributedString, replacementRange: textView.selectedRange)
            #endif
        }
    }
    
    public func strike() {
        if note.type == .RichText {
            if (attributedString.length > 0) {
                attributedString.removeAttribute(NSAttributedStringKey(rawValue: "NSStrikethrough"), range: selectedRange)
            }
            
            
            #if os(OSX)
                if (textView.typingAttributes[.strikethroughStyle] == nil) {
                    attributedString.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 2, range: selectedRange)
                    textView.typingAttributes[.strikethroughStyle] = 2
                } else {
                    textView.typingAttributes.removeValue(forKey: NSAttributedStringKey(rawValue: "NSStrikethrough"))
                }
            
                textView.insertText(attributedString, replacementRange: textView.selectedRange)
            #endif
        }
        
        if note.isMarkdown() {
            let string = "~~" + attributedString.string + "~~"
            let location = string.count == 4 ? range.location + 2 : range.upperBound + 4
            
            self.replaceWith(string: string)
            setSRange(NSMakeRange(location, 0))
        }
    }
    
    func tab() {
        guard let pRange = getParagraphRange() else { return }
        
        guard range.length > 0 else {
            #if os(OSX)
                let location = textView.selectedRange().location
                let text = storage.attributedSubstring(from: pRange).string
                textView.insertText("\t" + text, replacementRange: pRange)
                setSRange(NSMakeRange(location + 1, 0))
            #else
                replaceWith(string: "\t", range: range)
                setSRange(NSMakeRange(range.upperBound + 1, 0))
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
        
        setSRange(NSRange(location: pRange.lowerBound, length: result.count))
        
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
                setSRange(NSMakeRange(pRange.lowerBound - 1 + text.count, 0))
            #else
                // TODO: implement me!
                // replaceWith(string: text)
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
        
        setSRange(NSRange(location: pRange.lowerBound, length: result.count))
        
        if note.isMarkdown() {
            highlight()
        }
    }
    
    func header(_ string: String) {
        #if os(OSX)
            let prefix = string + " "
            let length = string.count + 1
        #else
            let prefix = string
            let length = 1
        #endif
        
        self.replaceWith(string: prefix, range: range)
        setSRange(NSMakeRange(range.location + length, 0))
    }
    
    public func link() {
        let text = "[" + attributedString.string + "]()"
        replaceWith(string: text, range: range)
        
        if (attributedString.length == 4) {
            setSRange(NSMakeRange(range.location + 1, 0))
        } else {
            setSRange(NSMakeRange(range.upperBound + 3, 0))
        }
    }
    
    public func image() {
        let text = "![" + attributedString.string + "]()"
        replaceWith(string: text)
        
        if (attributedString.length == 5) {
            setSRange(NSMakeRange(range.location + 2, 0))
        } else {
            setSRange(NSMakeRange(range.upperBound + 4, 0))
        }
    }
    
    func highlight() {
        let string = storage.string as NSString
        if let paragraphRange = getParagraphRange(), let codeBlockRange = NotesTextProcessor.getCodeBlockRange(paragraphRange: paragraphRange, string: string),
            codeBlockRange.upperBound <= storage.length,
            UserDefaultsManagement.codeBlockHighlight {
            NotesTextProcessor.highlightCode(range: codeBlockRange, storage: storage, string: string, note: note, async: true)
        }
    }
    
    func newLine() {
        guard let paragraphRange = getParagraphRange(), storage.length > paragraphRange.lowerBound - 1 else {
            return
        }
        
        let nsString = storage.string as NSString
        let prevParagraphRange = nsString.paragraphRange(for: NSMakeRange(paragraphRange.lowerBound - 1, 0))
        
        let prevString = nsString.substring(with: prevParagraphRange)
        let nsPrev = prevString as NSString
        
        guard let regex = try? NSRegularExpression(pattern: "^( |\t)*([-|–|—|*|•|\\+]{1} )"),
            let regexDigits = try? NSRegularExpression(pattern: "^(?: |\t)*([0-9])+\\. ") else {
            return
        }
        
        if let match = regex.firstMatch(in: prevString, range: NSRange(0..<nsPrev.length)) {
            let prefix = nsPrev.substring(with: match.range)
            
            if prevString == prefix + "\n" {
                #if os(OSX)
                    textView.setSelectedRange(prevParagraphRange)
                    textView.delete(nil)
                #else
                    textView.selectedRange = prevParagraphRange
                    textView.deleteBackward()
                #endif
                return
            }
            
            #if os(iOS)
                textView.insertText(prefix)
            #else
                textView.insertText(prefix, replacementRange: textView.selectedRange())
            #endif
            return
        }
        
        if let matchDigits = regexDigits.firstMatch(in: prevString, range: NSRange(0..<nsPrev.length)) {
            let prefix = nsPrev.substring(with: matchDigits.range)
            if prevString == prefix + "\n" {
                #if os(OSX)
                    textView.setSelectedRange(prevParagraphRange)
                    textView.delete(nil)
                #else
                    textView.selectedRange = prevParagraphRange
                    textView.deleteBackward()
                #endif
                return
            }
            
            if let position = Int(prefix.replacingOccurrences( of:"[^0-9]", with: "", options: .regularExpression)) {
                #if os(iOS)
                    textView.insertText(prefix.replacingOccurrences(of: String(position), with: String(position + 1)))
                #else
                    textView.insertText(prefix.replacingOccurrences(of: String(position), with: String(position + 1)), replacementRange: textView.selectedRange())
                #endif
                
            }
        }
    }
    
    #if os(OSX)
    public func toggleTodo() {
        guard let paragraphRange = getParagraphRange() else { return }
        
        let paragraph = self.storage.attributedSubstring(from: paragraphRange)
        let firstChar = paragraph.string.first
        
        if ["-", "+"].contains(firstChar) {
            let toggleChar = firstChar == "-" ? "+" : "-"
            let range = NSRange(location: paragraphRange.location, length: 1)
            
            textView.insertText(toggleChar, replacementRange: range)
        } else {
            let range = NSRange(location: paragraphRange.location, length: 0)
            
            textView.insertText("- ", replacementRange: range)
        }
    }
    #endif
    
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
        
            textView.undoManager?.beginUndoGrouping()
            textView.insertText(string, replacementRange: r)
            textView.undoManager?.endUndoGrouping()
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
        
        if note.isMarkdown(), let paragraphRange = getParagraphRange() {
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
                note.save(needImageUnLoad: true)
            }
        }
        
        #if os(iOS)
            textView.initUndoRedoButons()
        #endif
    }
    
    func getParagraphRange() -> NSRange? {
        let string = storage.string as NSString
        if range.upperBound <= string.length {
            let paragraph = string.paragraphRange(for: range)
            return paragraph
        }
        
        return nil
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
            if let font = textView.currentFont {
                return font
            }
        
            return textView.typingAttributes[NSAttributedStringKey.font.rawValue] as! Font
        #endif
    }
    
    func setTypingAttributes(font: Font) {
        #if os(OSX)
            textView.typingAttributes[.font] = font
        #else
            textView.typingFont = font
            textView.typingAttributes[NSAttributedStringKey.font.rawValue] = font
        #endif
    }
    
    func setSRange(_ range: NSRange) {
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
}

class UndoInfo: NSObject {
    let text: String
    let replacementRange: NSRange
    var string: NSAttributedString? = nil
    
    init(text: String, replacementRange: NSRange) {
        self.text = text
        self.replacementRange = replacementRange
    }
}
