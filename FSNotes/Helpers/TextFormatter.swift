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
    
    private var prevSelectedString: NSAttributedString
    private var prevSelectedRange: NSRange
    
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
        
        prevSelectedString = storage.attributedSubstring(from: range)
        prevSelectedRange = range
    }
    
    func getString() -> NSMutableAttributedString {
        return attributedString
    }
    
    func bold() {
        var charsDiff = 0
        
        if type == .Markdown {
            attributedString.mutableString.setString("**" + attributedString.string + "**")
            storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
            
            if (attributedString.length == 4) {
                setSRange(NSMakeRange(range.location + 2, 0))
            } else {
                setSRange(NSMakeRange(range.upperBound + 4, 0))
            }
            
            charsDiff = 4
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
        
        registerUndo(charsDiff)
    }
    
    func italic() {
        var charsDiff = 0
        
        if type == .Markdown {
            attributedString.mutableString.setString("_" + attributedString.string + "_")
            storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
            
            if (attributedString.length == 2) {
                setSRange(NSMakeRange(range.location + 1, 0))
            } else {
                setSRange(NSMakeRange(range.upperBound + 2, 0))
            }
            
            charsDiff = 2
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
        
        registerUndo(charsDiff)
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
            #endif
            
            storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
            registerUndo()
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
            #endif
            
            storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
            registerUndo()
        }
        
        if note.type == .Markdown {
            attributedString.mutableString.setString("~~" + attributedString.string + "~~")
            storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
            
            if (attributedString.length == 4) {
                setSRange(NSMakeRange(range.location + 2, 0))
            } else {
                setSRange(NSMakeRange(range.upperBound + 4, 0))
            }
            
            registerUndo(4)
        }
    }
    
    func tab() {
        let rangeLength = range.length
        
        #if os(OSX)
            if range.length == 0 {
                storage.replaceCharacters(in: range, with: "\t")
                setSRange(NSMakeRange(range.upperBound + 1, 0))
                
                if note.type == .Markdown {
                    highlight()
                }
                
                registerUndo(1)
                return
            }
        #else
            if range.length == 0, let cp = getParagraphRange() {
                range = NSMakeRange(cp.location, cp.length)
            }
        #endif
        
        guard storage.length >= range.upperBound, range.length > 0 else {
            #if os(iOS)
                storage.replaceCharacters(in: range, with: "\t")
                setSRange(NSMakeRange(range.upperBound + 1, 0))
                registerUndo(1)
            #endif
            return
        }
        
        let code = storage.attributedSubstring(from: range).string
        let lines = code.components(separatedBy: CharacterSet.newlines)
        
        var result: String = ""
        var added: Int = 0
        var diff = 0
        for line in lines {
            if lines.first == line {
                result += "\t" + line
                continue
            }
            added = added + 1
            result += "\n\t" + line
            diff += 1
        }
        
        storage.replaceCharacters(in: range, with: result)
        
        let newRange = NSRange(range.lowerBound..<range.upperBound + added + 1)
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
        
        registerUndo(diff + 1)
    }
    
    func unTab() {
        var initialLocation = 0
        
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
        var diff = 1
        for var line in lines {
            if line.starts(with: "\t") {
                removed = removed + 1
                diff += 1
                line.removeFirst()
            }
            
            if line.starts(with: " ") {
                removed = removed + 1
                diff += 1
                line.removeFirst()
            }
            
            result.append(line)
        }
        
        let x = result.joined(separator: "\n")
        storage.replaceCharacters(in: range, with: x)
        
        var newRange = NSRange(range.lowerBound..<range.upperBound - removed + 1)
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
        
        registerUndo(-diff)
    }
    
    func header(_ string: String) {
        #if os(OSX)
            let prefix = string + " "
        #else
            let prefix = string
        #endif
        
        attributedString.mutableString.setString(prefix + attributedString.string)
        storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
        
        setSRange(NSMakeRange(range.upperBound + 1 + string.count, 0))
        registerUndo(string.count + 1)
    }
    
    public func link() {
        let text = "[" + attributedString.string + "]()"
        attributedString.mutableString.setString(text)
        storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
        
        if (attributedString.length == 4) {
            setSRange(NSMakeRange(range.location + 1, 0))
        } else {
            setSRange(NSMakeRange(range.upperBound + 3, 0))
        }
        
        registerUndo(4)
    }
    
    public func image() {
        let text = "![" + attributedString.string + "]()"
        attributedString.mutableString.setString(text)
        storage.replaceCharacters(in: textView.selectedRange, with: attributedString)
        
        if (attributedString.length == 5) {
            setSRange(NSMakeRange(range.location + 2, 0))
        } else {
            setSRange(NSMakeRange(range.upperBound + 4, 0))
        }
        
        registerUndo(5)
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
    
    private func registerUndo(_ charsDiff: Int = 0) {
        let string = prevSelectedString
        let range = prevSelectedRange
        var rangeDiff: NSRange = range
        
        if let etv = textView as? EditTextView {
            if charsDiff != 0  {
                rangeDiff = NSMakeRange(range.lowerBound, range.length + charsDiff )
            }
            
            #if os(OSX)
                let undo = UndoData(string: string, range: rangeDiff)
                note.undoManager.registerUndo(withTarget: etv, selector: #selector(etv.undoEdit), object: undo)
            #endif
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
            if range.upperBound < storage.length {
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
