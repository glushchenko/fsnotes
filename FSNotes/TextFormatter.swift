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
    
    init(textView: TextView, note: Note) {
        #if os(OSX)
            storage = textView.textStorage!
            range = textView.selectedRange()
            attributedSelected = textView.attributedString()
        #else
            storage = textView.textStorage
            range = textView.selectedRange
            attributedSelected = textView.attributedText
        #endif
        
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
    
    deinit {
        if note.type == .Markdown, let paragraphRange = getParagraphRange() {
            NotesTextProcessor.scanMarkdownSyntax(storage, paragraphRange: paragraphRange, note: note)
        }
        
        if note.type == .RichText {
            setSRange(range)
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
}
