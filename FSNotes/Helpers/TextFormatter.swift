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
    typealias TextView = NSTextView
#else
    import UIKit
    typealias Font = UIFont
    typealias TextView = UITextView
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
    
    init(textView: TextView, note: Note) {
        #if os(OSX)
            storage = textView.textStorage!
            range = textView.selectedRange
            attributedSelected = textView.attributedString()
        #else
            storage = textView.textStorage
            range = textView.selectedRange
            attributedSelected = textView.attributedText
        #endif
        
        self.maxWidth = textView.frame.width
        self.attributedString = NSMutableAttributedString(attributedString: attributedSelected.attributedSubstring(from: range))
        self.selectedRange = NSRange(0..<attributedString.length)
        
        self.type = note.type
        self.textView = textView
        self.note = note
    }
    
    func getString() -> NSMutableAttributedString {
        return attributedString
    }
    
    func bold() {
        if type == .Markdown {
            attributedString.mutableString.setString("**" + attributedString.string + "**")
            storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
            
            if (attributedString.length == 4) {
                setSRange(NSMakeRange(range.location + 2, 0))
            } else {
                setSRange(NSMakeRange(range.upperBound + 4, 0))
            }
        }
        
        if type == .RichText {
            if (attributedString.length > 0) {
                let font = attributedString.attribute(.font, at: 0, longestEffectiveRange: nil, in: selectedRange) as! Font
                
                let newFont = toggleBoldFont(font: font)
                attributedString.addAttribute(.font, value: newFont, range: selectedRange)
            }
            
            let newFont = toggleBoldFont(font: getTypingAttributes())
            setTypingAttributes(font: newFont)
            
            storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
        }
    }
    
    func italic() {
        if type == .Markdown {
            attributedString.mutableString.setString("_" + attributedString.string + "_")
            storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
            
            if (attributedString.length == 2) {
                setSRange(NSMakeRange(range.location + 1, 0))
            } else {
                setSRange(NSMakeRange(range.upperBound + 2, 0))
            }
        }
        
        if type == .RichText {
            if (attributedString.length > 0) {
                let font = attributedString.attribute(.font, at: 0, longestEffectiveRange: nil, in: selectedRange) as! Font
                
                let newFont = toggleItalicFont(font: font)
                attributedString.addAttribute(.font, value: newFont, range: selectedRange)
            }
            
            let newFont = toggleItalicFont(font: getTypingAttributes())
            setTypingAttributes(font: newFont)
            
            storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
        }
    }
    
    @objc func tab(_ undoInfo: UndoInfo? = nil) {
        let rangeLength = range.length
        
        #if os(OSX)
            if range.length == 0 {
                storage.replaceCharacters(in: range, with: "\t")
                setSRange(NSMakeRange(range.upperBound + 1, 0))
                
                if note.type == .Markdown {
                    highlight()
                }
                return
            }
        #else
            if range.length == 0, let cp = getParagraphRange() {
                range = NSMakeRange(cp.location, cp.length)
            }
        #endif
        
        if let undo = undoInfo {
            range = undo.replacementRange
        }

        guard storage.length >= range.upperBound, range.length > 0 else {
            #if os(iOS)
                storage.replaceCharacters(in: range, with: "\t")
                setSRange(NSMakeRange(range.upperBound + 1, 0))
            #endif
            return
        }
        
        let code = storage.attributedSubstring(from: range).string
        let lines = code.components(separatedBy: CharacterSet.newlines)
        
        var result: String = ""
        var added: Int = 0
        for line in lines {
            if lines.first == line {
                result += "\t" + line
                continue
            }
            added = added + 1
            result += "\n\t" + line
        }
        
        storage.replaceCharacters(in: range, with: result)
        
        let newRange = NSRange(range.lowerBound..<range.upperBound + added + 1)
        let undoInfo = UndoInfo(text: result, replacementRange: newRange)
        textView.undoManager?.registerUndo(withTarget: self, selector: #selector(unTab), object: undoInfo)
        
        if let note = EditTextView.note, note.type == .Markdown {
            note.content = NSMutableAttributedString(attributedString: getAttributedString())
            let async = newRange.length > 1000
            NotesTextProcessor.fullScan(note: note, storage: storage, range: newRange, async: async)
            note.save()
        }
        
        if rangeLength > 0 {
            setSRange(newRange)
        } else {
            setSRange(NSMakeRange(newRange.upperBound, 0))
        }
        
        if note.type == .Markdown {
            highlight()
        }
    }
    
    @objc func unTab(_ undoInfo: UndoInfo? = nil) {
        guard let undo = textView.undoManager else {
            return
        }
        
        var initialLocation = 0
        if let undo = undoInfo {
            range = undo.replacementRange
        }
        
        guard storage.length >= range.location + range.length else {
            return
        }
        
        var code = storage.mutableString.substring(with: range)
        if range.length == 0 {
            initialLocation = range.location
            let string = storage.string as NSString
            range = string.paragraphRange(for: range)
            code = storage.attributedSubstring(from: range).string
        }
        
        let lines = code.components(separatedBy: CharacterSet.newlines)
        
        var result: [String] = []
        var removed: Int = 1
        for var line in lines {
            if line.starts(with: "\t") {
                removed = removed + 1
                line.removeFirst()
            }
            
            if line.starts(with: " ") {
                removed = removed + 1
                line.removeFirst()
            }
            
            result.append(line)
        }
        
        let x = result.joined(separator: "\n")
        storage.replaceCharacters(in: range, with: x)
        
        var newRange = NSRange(range.lowerBound..<range.upperBound - removed + 1)
        let undoInfo = UndoInfo(text: x, replacementRange: newRange)
        undo.registerUndo(withTarget: self, selector: #selector(tab), object: undoInfo)
        
        if let note = EditTextView.note, note.type == .Markdown {
            note.content = NSMutableAttributedString(attributedString: getAttributedString())
            let async = newRange.length > 1000
            NotesTextProcessor.fullScan(note: note, storage: storage, range: newRange, async: async)
            
            note.save()
        }
        
        if initialLocation > 0 {
            newRange = NSMakeRange(initialLocation - removed + 1, 0)
        }
        
        setSRange(newRange)
        range = newRange
        
        if note.type == .Markdown {
            highlight()
        }
    }
    
    func header() {
        storage.replaceCharacters(in: range, with: "#")
        setSRange(NSMakeRange(range.upperBound + 1, 0))
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
            let regexDigits = try? NSRegularExpression(pattern: "^(?: |\t)*([0-9])+. ") else {
            return
        }
        
        if let match = regex.firstMatch(in: prevString, range: NSRange(0..<nsPrev.length)) {
            let prefix = nsPrev.substring(with: match.range)
            
            if prevString == prefix + "\n" {
                setSRange(prevParagraphRange)
                textView.delete(self)
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
                setSRange(prevParagraphRange)
                textView.delete(self)
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
    
    deinit {
        if note.type == .Markdown {
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
        
        if note.type == .Markdown, let paragraphRange = getParagraphRange() {
            NotesTextProcessor.scanMarkdownSyntax(storage, paragraphRange: paragraphRange, note: note)
        }
        
        if note.type == .Markdown || note.type == .RichText {
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
    }
    
    func getParagraphRange() -> NSRange? {
        let string = storage.string as NSString
        let paragraph = string.paragraphRange(for: range)
        
        return paragraph
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
            return textView.typingAttributes[NSAttributedStringKey.font.rawValue] as! Font
        #endif
    }
    
    func setTypingAttributes(font: Font) {
        #if os(OSX)
            textView.typingAttributes[.font] = font
        #else
            textView.typingAttributes[NSAttributedStringKey.font.rawValue] = font
        #endif
    }
    
    func setSRange(_ range: NSRange) {
        #if os(OSX)
            textView.setSelectedRange(range)
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
    
    init(text: String, replacementRange: NSRange) {
        self.text = text
        self.replacementRange = replacementRange
    }
}
