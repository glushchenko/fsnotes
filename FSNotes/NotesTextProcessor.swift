//
//  NotesTextStorage.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 12/26/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Highlightr

public class NotesTextProcessor {
    // MARK: Syntax highlight customisation
    
    /**
     Color used to highlight markdown syntax. Default value is light grey.
     */
    open static var syntaxColor = NSColor.lightGray
    
    open static var codeBackground = NSColor(red:0.97, green:0.97, blue:0.97, alpha:1.0)
    
    /**
     Quote indentation in points. Default 20.
     */
    open var quoteIndendation : CGFloat = 20
    
    public static var codeFont = NSFont(name: "Source Code Pro", size: CGFloat(UserDefaultsManagement.fontSize))
    
    /**
     If the markdown syntax should be hidden or visible
     */
    open static var hideSyntax = false
    
    public static func isCodeBlockParagraph(_ paragraph: String) -> Bool {
        if (paragraph.starts(with: "\t") || paragraph.starts(with: "    ")) {
            return true
        }
        
        return false
    }
    
    public static func getFencedCodeBlockRange(paragraphRange: NSRange, string: NSString) -> NSRange? {
        let regex = try! NSRegularExpression(pattern: NotesTextProcessor._codeQuoteBlockPattern, options: [
            NSRegularExpression.Options.allowCommentsAndWhitespace,
            NSRegularExpression.Options.anchorsMatchLines
            ])
        
        var foundRange: NSRange? = nil
        regex.enumerateMatches(
            in: string as String,
            options: NSRegularExpression.MatchingOptions(),
            range: NSRange(0..<string.length),
            using: { (result, matchingFlags, stop) -> Void in
                guard let r = result else {
                    return
                }
                
                if r.range.upperBound >= paragraphRange.location && r.range.lowerBound <= paragraphRange.location {
                    foundRange = r.range
                    stop.pointee = true
                }
            }
        )
        
        return foundRange
    }
    
    public static func getCodeBlockRange(paragraphRange: NSRange, string: NSString) -> NSRange? {
        let paragraph = string.substring(with: paragraphRange)
        guard isCodeBlockParagraph(paragraph) else {
            return nil
        }
        
        let start = NotesTextProcessor.scanPrevParagraph(string: string, location: paragraphRange.lowerBound - 1)!
        let end = NotesTextProcessor.scanNextParagraph(string: string, location: paragraphRange.upperBound + 1)!
        
        NotesTextProcessor.i = 0
        NotesTextProcessor.j = 0
        
        return NSRange(start..<end)
    }
    
    public static var j = 0
    public static func scanPrevParagraph(string: NSString, location: Int) -> Int? {
        NotesTextProcessor.j = NotesTextProcessor.j + 1
        guard NotesTextProcessor.j < 100 else {
            return location + 1
        }
        guard location > 0 else {
            return location + 1
        }
        
        let range = string.paragraphRange(for: NSRange(location: location, length: 0))
        let substring = string.substring(with: range)
        if NotesTextProcessor.isCodeBlockParagraph(substring) {
            return NotesTextProcessor.scanPrevParagraph(string: string, location: range.lowerBound - 1)
        }
        
        return location + 1
    }
    
    public static var i = 0
    public static func scanNextParagraph(string: NSString, location: Int) -> Int? {
        NotesTextProcessor.i = NotesTextProcessor.i + 1

        guard NotesTextProcessor.i < 100 else {
            return location - 1
        }
        guard location < string.length + 1 else {
            return location - 1
        }
    
        let range = string.paragraphRange(for: NSRange(location: location, length: 0))
        let substring = string.substring(with: range)
        if NotesTextProcessor.isCodeBlockParagraph(substring) {
            return NotesTextProcessor.scanNextParagraph(string: string, location: range.upperBound + 1)
        }
        
        return location - 2
    }
    
    public static var hl: Highlightr? = nil
    
    public static func getHighlighter() -> Highlightr? {
        if let instance = self.hl {
            return instance
        }
        
        guard let highlightr = Highlightr() else {
            return nil
        }
        
        highlightr.setTheme(to: UserDefaultsManagement.codeTheme)
        self.hl = highlightr
        
        return self.hl
    }
    
    public static func fullScan(note: Note, storage: NSTextStorage? = nil, range: NSRange? = nil, async: Bool = false) {
        self.scanBasicSyntax(note: note, storage: storage, range: range)
        
        if let unwrappedStorage = storage {
            note.content = NSMutableAttributedString(attributedString: unwrappedStorage.attributedSubstring(from: NSRange(0..<unwrappedStorage.length)))
        }
        
        self.scanCodeBlock(pattern: self._codeBlockPattern, options: [
                NSRegularExpression.Options.allowCommentsAndWhitespace,
                NSRegularExpression.Options.anchorsMatchLines
            ], storage: storage, note: note, async: async)
        
        self.scanCodeBlock(pattern: self._codeQuoteBlockPattern, options: [
                NSRegularExpression.Options.allowCommentsAndWhitespace,
                NSRegularExpression.Options.anchorsMatchLines
            ], storage: storage, note: note, async: async)
    }
    
    public static func scanBasicSyntax(note: Note, storage: NSTextStorage? = nil, range: NSRange? = nil) {
        var affectedRange: NSRange
        
        if let r = range {
            affectedRange = r
        } else {
            affectedRange = NSRange(0..<note.content.length)
        }
        
        let target = storage != nil ? storage! : note.content
        
        self.scanMarkdownSyntax(target, paragraphRange: affectedRange)
    }
    
    public static func highlight(_ code: String, language: String? = nil) -> NSAttributedString? {
        if let highlighter = NotesTextProcessor.getHighlighter() {
            if let result = highlighter.highlight(code, as: language) {
                return result
            }
        }
        return nil
    }
    
    public static func updateStorage(range: NSRange, code: NSAttributedString, storage: NSTextStorage?, string: NSString, note: Note) {
        let content: NSAttributedString
        if let storageUnwrapped = storage {
            content = storageUnwrapped
        } else {
            content = note.content
        }
        
        if ((range.location + range.length) > content.length) {
            return
        }
        
        if (code.string != content.attributedSubstring(from: range).string) {
            return
        }
        
        let isActiveStorage = (EditTextView.note == note)
        
        if isActiveStorage {
            storage?.beginEditing()
        }
        
        code.enumerateAttributes(
            in: NSMakeRange(0, code.length),
            options: [],
            using: { (attrs, locRange, stop) in
                var fixedRange = NSMakeRange(range.location+locRange.location, locRange.length)
                fixedRange.length = (fixedRange.location + fixedRange.length < string.length) ? fixedRange.length : string.length-fixedRange.location
                fixedRange.length = (fixedRange.length >= 0) ? fixedRange.length : 0
                
                if isActiveStorage {
                    storage?.setAttributes(attrs, range: fixedRange)
                }
                
                note.content.setAttributes(attrs, range: fixedRange)
            }
        )
        
        if let font = NotesTextProcessor.codeFont {
            if isActiveStorage {
                storage?.addAttributes([.font: font], range: range)
            }
            
            note.content.addAttributes([.font: font], range: range)
        }
        
        if isActiveStorage {
            storage?.endEditing()
            storage?.edited(NSTextStorageEditActions.editedAttributes, range: range, changeInLength: 0)
            storage?.addAttributes([
                .backgroundColor: NSColor(red:0.97, green:0.97, blue:0.97, alpha:1.0)
                ], range: range)
        }

        note.content.addAttributes([
                    .backgroundColor: NotesTextProcessor.codeBackground
                ], range: range)
    }
    
    public static func highlightCode(range: NSRange, storage: NSTextStorage?, string: NSString, note: Note, async: Bool = true) {
        let codeRange = string.substring(with: range)
        let preDefinedLanguage = self.getLanguage(codeRange)
        
        if async {
            DispatchQueue.global().async {
                if let code = self.highlight(codeRange, language: preDefinedLanguage) {
                    DispatchQueue.main.async(execute: {
                        NotesTextProcessor.updateStorage(range: range, code: code, storage: storage, string: string, note: note)
                    })
                }
            }
            
            return
        }
            
        if let code = NotesTextProcessor.highlight(codeRange, language: preDefinedLanguage) {
            NotesTextProcessor.updateStorage(range: range, code: code, storage: storage, string: string, note: note)
        }
    }
    
    fileprivate static var quoteIndendationStyle : NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = CGFloat(20)
        return paragraphStyle
    }
    
    public static var languages: [String]? = nil
    
    public static func scanCodeBlock(pattern: String, options: NSRegularExpression.Options, storage: NSTextStorage?, note: Note, async: Bool = false) {
        let content = storage != nil ? storage! : note.content
        let range = NSMakeRange(0, content.length)
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        
        regex.enumerateMatches(
            in: content.string,
            options: NSRegularExpression.MatchingOptions(),
            range: range,
            using: { (result, matchingFlags, stop) -> Void in
                guard let r = result else {
                    return
                }
                let string = (content.string as NSString)
                let paragraphRange = string.paragraphRange(for: r.range)
                var foundRange: NSRange?
                
                if pattern == self._codeBlockPattern {
                    if let codeBlockRange = NotesTextProcessor.getCodeBlockRange(paragraphRange: paragraphRange, string: string),
                        codeBlockRange.upperBound <= content.length {
                        foundRange = codeBlockRange
                    }
                } else {
                    if let fencedCodeBlockRange = NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: paragraphRange, string: string),
                        fencedCodeBlockRange.upperBound <= content.length {
                        foundRange = fencedCodeBlockRange
                    }
                }
                
                if let fr = foundRange {
                    NotesTextProcessor.highlightCode(range: fr, storage: storage, string: string, note: note, async: async)
                }
            }
        )
    }
    
    public static func getLanguage(_ code: String) -> String? {
        if code.starts(with: "```") {
            if let newLinePosition = code.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines) {
                let newLineOffset = newLinePosition.lowerBound.encodedOffset
                if newLineOffset > 3 {
                    let start = code.index(code.startIndex, offsetBy: 3)
                    let end = code.index(code.startIndex, offsetBy: newLineOffset)
                    let range = start..<end
                    
                    if self.languages == nil {
                        self.languages = self.getHighlighter()?.supportedLanguages()
                    }
                    
                    if let lang = self.languages, lang.contains(String(code[range])) {
                        return String(code[range])
                    }
                }
            }
        }
        
        return nil
    }
    
    public static func scanMarkdownSyntax(_ styleApplier: NSMutableAttributedString, paragraphRange: NSRange) {
        
        let textStorageNSString = styleApplier.string as NSString
        let string =  styleApplier.string
        
        let codeFont = NotesTextProcessor.codeFont(CGFloat(UserDefaultsManagement.fontSize))
        let quoteFont = NotesTextProcessor.quoteFont(CGFloat(UserDefaultsManagement.fontSize))
        let boldFont = NSFont.boldFont()
        let italicFont = NSFont.italicFont()
        
        let hiddenFont = NSFont.systemFont(ofSize: 0.1)
        let hiddenColor = NSColor.clear
        let hiddenAttributes: [NSAttributedStringKey : Any] = [
            .font : hiddenFont,
            .foregroundColor : hiddenColor
        ]
        
        func hideSyntaxIfNecessary(range: @autoclosure () -> NSRange) {
            guard NotesTextProcessor.hideSyntax else { return }
            
            styleApplier.addAttributes(hiddenAttributes, range: range())
        }
        

        // Reset highlightr
        
        styleApplier.removeAttribute(.backgroundColor, range: paragraphRange)
        styleApplier.addAttribute(.font, value: UserDefaultsManagement.noteFont, range: paragraphRange)
        styleApplier.addAttribute(.foregroundColor, value: UserDefaultsManagement.fontColor, range: paragraphRange)
        
        // We detect and process inline links not formatted
        NotesTextProcessor.autolinkRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            let substring = textStorageNSString.substring(with: range)
            guard substring.lengthOfBytes(using: .utf8) > 0 else { return }
            styleApplier.addAttribute(.link, value: substring, range: range)
            
            if NotesTextProcessor.hideSyntax {
                NotesTextProcessor.autolinkPrefixRegex.matches(string, range: range) { (innerResult) -> Void in
                    guard let innerRange = innerResult?.range else { return }
                    styleApplier.addAttribute(.font, value: hiddenFont, range: innerRange)
                    styleApplier.addAttribute(.foregroundColor, value: hiddenColor, range: innerRange)
                }
            }
        }
        
        // We detect and process underlined headers
        NotesTextProcessor.headersSetextRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: boldFont, range: range)
            NotesTextProcessor.headersSetextUnderlineRegex.matches(string, range: paragraphRange) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: NSMakeRange(innerRange.location, innerRange.length))
            }
        }
        
        // We detect and process dashed headers
        NotesTextProcessor.headersAtxRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: boldFont, range: range)
            NotesTextProcessor.headersAtxOpeningRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                let syntaxRange = NSMakeRange(innerRange.location, innerRange.length + 1)
                hideSyntaxIfNecessary(range: syntaxRange)
            }
            NotesTextProcessor.headersAtxClosingRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: innerRange)
            }
        }
        
        // We detect and process reference links
        NotesTextProcessor.referenceLinkRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: range)
        }
        
        // We detect and process lists
        NotesTextProcessor.listRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            NotesTextProcessor.listOpeningRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
            }
        }
        
        // We detect and process anchors (links)
        NotesTextProcessor.anchorRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: codeFont, range: range)
            NotesTextProcessor.openingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
            }
            NotesTextProcessor.closingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
            }
            NotesTextProcessor.parenRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                let initialSyntaxRange = NSMakeRange(innerRange.location, 1)
                let finalSyntaxRange = NSMakeRange(innerRange.location + innerRange.length - 1, 1)
                hideSyntaxIfNecessary(range: initialSyntaxRange)
                hideSyntaxIfNecessary(range: finalSyntaxRange)
            }
        }
        
        // We detect and process inline anchors (links)
        NotesTextProcessor.anchorInlineRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: codeFont, range: range)
            
            var destinationLink : String?
            
            NotesTextProcessor.coupleRoundRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                
                var _range = innerRange
                _range.location = range.location + 1
                _range.length = range.length - 2
                
                let substring = textStorageNSString.substring(with: _range)
                guard substring.lengthOfBytes(using: .utf8) > 0 else { return }
                
                destinationLink = substring
                styleApplier.addAttribute(.link, value: substring, range: _range)
                
                hideSyntaxIfNecessary(range: innerRange)
            }
            
            NotesTextProcessor.openingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: innerRange)
            }
            
            NotesTextProcessor.closingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: innerRange)
            }
            
            guard let destinationLinkString = destinationLink else { return }
            
            NotesTextProcessor.coupleSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                var _range = innerRange
                _range.location = _range.location + 1
                _range.length = _range.length - 2
                
                let substring = textStorageNSString.substring(with: _range)
                guard substring.lengthOfBytes(using: .utf8) > 0 else { return }
                
                styleApplier.addAttribute(.link, value: destinationLinkString, range: _range)
            }
        }
        
        NotesTextProcessor.imageRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: codeFont, range: range)
            
            // TODO: add image attachment
            if NotesTextProcessor.hideSyntax {
                styleApplier.addAttribute(.font, value: hiddenFont, range: range)
            }
            NotesTextProcessor.imageOpeningSquareRegex.matches(string, range: paragraphRange) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
            }
            NotesTextProcessor.imageClosingSquareRegex.matches(string, range: paragraphRange) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
            }
        }
        
        // We detect and process quotes
        NotesTextProcessor.blockQuoteRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: quoteFont, range: range)
            styleApplier.addAttribute(.foregroundColor, value: NSColor.darkGray, range: range)
            styleApplier.addAttribute(.paragraphStyle, value: quoteIndendationStyle, range: range)
            NotesTextProcessor.blockQuoteOpeningRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: innerRange)
            }
        }
        
        // We detect and process strict italics
        NotesTextProcessor.strictItalicRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: italicFont, range: range)
            let substring = textStorageNSString.substring(with: NSMakeRange(range.location, 1))
            var start = 0
            if substring == " " {
                start = 1
            }
            
            let preRange = NSMakeRange(range.location + start, 1)
            hideSyntaxIfNecessary(range: preRange)
            styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: preRange)
            
            let postRange = NSMakeRange(range.location + range.length - 1, 1)
            styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: postRange)
            hideSyntaxIfNecessary(range: postRange)
        }
        
        // We detect and process strict bolds
        NotesTextProcessor.strictBoldRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: boldFont, range: range)
            let substring = textStorageNSString.substring(with: NSMakeRange(range.location, 1))
            var start = 0
            if substring == " " {
                start = 1
            }
            
            let preRange = NSMakeRange(range.location + start, 2)
            styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: preRange)
            hideSyntaxIfNecessary(range: preRange)
            
            let postRange = NSMakeRange(range.location + range.length - 2, 2)
            styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: postRange)
            hideSyntaxIfNecessary(range: postRange)
        }
        
        // We detect and process italics
        NotesTextProcessor.italicRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: italicFont, range: range)
            
            let preRange = NSMakeRange(range.location, 1)
            styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: preRange)
            hideSyntaxIfNecessary(range: preRange)
            
            let postRange = NSMakeRange(range.location + range.length - 1, 1)
            styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: postRange)
            hideSyntaxIfNecessary(range: postRange)
        }
        
        // We detect and process bolds
        NotesTextProcessor.boldRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: boldFont, range: range)
            
            let preRange = NSMakeRange(range.location, 2)
            styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: preRange)
            hideSyntaxIfNecessary(range: preRange)
            
            let postRange = NSMakeRange(range.location + range.length - 2, 2)
            styleApplier.addAttribute(.foregroundColor, value: NotesTextProcessor.syntaxColor, range: postRange)
            hideSyntaxIfNecessary(range: postRange)
        }
        
        // We detect and process inline mailto links not formatted
        NotesTextProcessor.autolinkEmailRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            let substring = textStorageNSString.substring(with: range)
            guard substring.lengthOfBytes(using: .utf8) > 0 else { return }
            styleApplier.addAttribute(.link, value: substring, range: range)
            
            if NotesTextProcessor.hideSyntax {
                NotesTextProcessor.mailtoRegex.matches(string, range: range) { (innerResult) -> Void in
                    guard let innerRange = innerResult?.range else { return }
                    styleApplier.addAttribute(.font, value: hiddenFont, range: innerRange)
                    styleApplier.addAttribute(.foregroundColor, value: hiddenColor, range: innerRange)
                }
            }
        }
    }
    
    /// Tabs are automatically converted to spaces as part of the transform
    /// this constant determines how "wide" those tabs become in spaces
    public static let _tabWidth = 4
    
    // MARK: Headers
    
    /*
     Head
     ======
     
     Subhead
     -------
     */
    
    fileprivate static let headerSetextPattern = [
        "^(.+?)",
        "\\p{Z}*",
        "\\n",
        "(=+|-+)",  // $1 = string of ='s or -'s
        "\\p{Z}*",
        "\\n+|\\Z"
        ].joined(separator: "\n")
    
    public static let headersSetextRegex = MarklightRegex(pattern: headerSetextPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    fileprivate static let setextUnderlinePattern = [
        "(==+|--+)     # $1 = string of ='s or -'s",
        "\\p{Z}*$"
        ].joined(separator: "\n")
    
    public static let headersSetextUnderlineRegex = MarklightRegex(pattern: setextUnderlinePattern, options: [.allowCommentsAndWhitespace])
    
    /*
     # Head
     
     ## Subhead ##
     */
    
    fileprivate static let headerAtxPattern = [
        "^(\\#{1,6})  # $1 = string of #'s",
        "\\p{Z}*",
        "(.+?)        # $2 = Header text",
        "\\p{Z}*",
        "\\#*         # optional closing #'s (not counted)",
        "(?:\\n+|\\Z)"
        ].joined(separator: "\n")
    
    public static let headersAtxRegex = MarklightRegex(pattern: headerAtxPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    fileprivate static let headersAtxOpeningPattern = [
        "^(\\#{1,6})"
        ].joined(separator: "\n")
    
    public static let headersAtxOpeningRegex = MarklightRegex(pattern: headersAtxOpeningPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    fileprivate static let headersAtxClosingPattern = [
        "\\#{1,6}(?:\\n+|\\Z)"
        ].joined(separator: "\n")
    
    public static let headersAtxClosingRegex = MarklightRegex(pattern: headersAtxClosingPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    // MARK: Reference links
    
    /*
     TODO: we don't know how reference links are formed
     */
    
    fileprivate static let referenceLinkPattern = [
        "^\\p{Z}{0,\(_tabWidth - 1)}\\[([^\\[\\]]+)\\]:  # id = $1",
        "  \\p{Z}*",
        "  \\n?                   # maybe *one* newline",
        "  \\p{Z}*",
        "<?(\\S+?)>?              # url = $2",
        "  \\p{Z}*",
        "  \\n?                   # maybe one newline",
        "  \\p{Z}*",
        "(?:",
        "    (?<=\\s)             # lookbehind for whitespace",
        "    [\"(]",
        "    (.+?)                # title = $3",
        "    [\")]",
        "    \\p{Z}*",
        ")?                       # title is optional",
        "(?:\\n+|\\Z)"
        ].joined(separator: "")
    
    public static let referenceLinkRegex = MarklightRegex(pattern: referenceLinkPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    // MARK: Lists
    
    /*
     * First element
     * Second element
     */
    
    fileprivate static let _markerUL = "[*+-]"
    fileprivate static let _markerOL = "\\d+[.]"
    
    fileprivate static let _listMarker = "(?:\(_markerUL)|\(_markerOL))"
    fileprivate static let _wholeList = [
        "(                               # $1 = whole list",
        "  (                             # $2",
        "    \\p{Z}{0,\(_tabWidth - 1)}",
        "    (\(_listMarker))            # $3 = first list item marker",
        "    \\p{Z}+",
        "  )",
        "  (?s:.+?)",
        "  (                             # $4",
        "      \\z",
        "    |",
        "      \\n{2,}",
        "      (?=\\S)",
        "      (?!                       # Negative lookahead for another list item marker",
        "        \\p{Z}*",
        "        \(_listMarker)\\p{Z}+",
        "      )",
        "  )",
        ")"
        ].joined(separator: "\n")
    
    fileprivate static let listPattern = "(?:(?<=\\n\\n)|\\A\\n?)" + _wholeList
    
    public static let listRegex = MarklightRegex(pattern: listPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    public static let listOpeningRegex = MarklightRegex(pattern: _listMarker, options: [.allowCommentsAndWhitespace])
    
    // MARK: Anchors
    
    /*
     [Title](http://example.com)
     */
    
    fileprivate static let anchorPattern = [
        "(                                  # wrap whole match in $1",
        "    \\[",
        "        (\(NotesTextProcessor.getNestedBracketsPattern()))  # link text = $2",
        "    \\]",
        "",
        "    \\p{Z}?                        # one optional space",
        "    (?:\\n\\p{Z}*)?                # one optional newline followed by spaces",
        "",
        "    \\[",
        "        (.*?)                      # id = $3",
        "    \\]",
        ")"
        ].joined(separator: "\n")
    
    public static let anchorRegex = MarklightRegex(pattern: anchorPattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    fileprivate static let opneningSquarePattern = [
        "(\\[)"
        ].joined(separator: "\n")
    
    public static let openingSquareRegex = MarklightRegex(pattern: opneningSquarePattern, options: [.allowCommentsAndWhitespace])
    
    fileprivate static let closingSquarePattern = [
        "\\]"
        ].joined(separator: "\n")
    
    public static let closingSquareRegex = MarklightRegex(pattern: closingSquarePattern, options: [.allowCommentsAndWhitespace])
    
    fileprivate static let coupleSquarePattern = [
        "\\[(.*?)\\]"
        ].joined(separator: "\n")
    
    public static let coupleSquareRegex = MarklightRegex(pattern: coupleSquarePattern, options: [])
    
    fileprivate static let coupleRoundPattern = [
        "\\((.*?)\\)"
        ].joined(separator: "\n")
    
    public static let coupleRoundRegex = MarklightRegex(pattern: coupleRoundPattern, options: [])
    
    fileprivate static let parenPattern = [
        "(",
        "\\(                 # literal paren",
        "      \\p{Z}*",
        "      (\(NotesTextProcessor.getNestedParensPattern()))    # href = $3",
        "      \\p{Z}*",
        "      (               # $4",
        "      (['\"])         # quote char = $5",
        "      (.*?)           # title = $6",
        "      \\5             # matching quote",
        "      \\p{Z}*",
        "      )?              # title is optional",
        "  \\)",
        ")"
        ].joined(separator: "\n")
    
    public static let parenRegex = MarklightRegex(pattern: parenPattern, options: [.allowCommentsAndWhitespace])
    
    fileprivate static let anchorInlinePattern = [
        "(                           # wrap whole match in $1",
        "    \\[",
        "        (\(NotesTextProcessor.getNestedBracketsPattern()))   # link text = $2",
        "    \\]",
        "    \\(                     # literal paren",
        "        \\p{Z}*",
        "        (\(NotesTextProcessor.getNestedParensPattern()))   # href = $3",
        "        \\p{Z}*",
        "        (                   # $4",
        "        (['\"])           # quote char = $5",
        "        (.*?)               # title = $6",
        "        \\5                 # matching quote",
        "        \\p{Z}*                # ignore any spaces between closing quote and )",
        "        )?                  # title is optional",
        "    \\)",
        ")"
        ].joined(separator: "\n")
    
    public static let anchorInlineRegex = MarklightRegex(pattern: anchorInlinePattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    // Mark: Images
    
    /*
     ![Title](http://example.com/image.png)
     */
    
    fileprivate static let imagePattern = [
        "(               # wrap whole match in $1",
        "!\\[",
        "    (.*?)       # alt text = $2",
        "\\]",
        "",
        "\\p{Z}?            # one optional space",
        "(?:\\n\\p{Z}*)?    # one optional newline followed by spaces",
        "",
        "\\[",
        "    (.*?)       # id = $3",
        "\\]",
        "",
        ")"
        ].joined(separator: "\n")
    
    public static let imageRegex = MarklightRegex(pattern: imagePattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    fileprivate static let imageOpeningSquarePattern = [
        "(!\\[)"
        ].joined(separator: "\n")
    
    public static let imageOpeningSquareRegex = MarklightRegex(pattern: imageOpeningSquarePattern, options: [.allowCommentsAndWhitespace])
    
    fileprivate static let imageClosingSquarePattern = [
        "(\\])"
        ].joined(separator: "\n")
    
    public static let imageClosingSquareRegex = MarklightRegex(pattern: imageClosingSquarePattern, options: [.allowCommentsAndWhitespace])
    
    fileprivate static let imageInlinePattern = [
        "(                     # wrap whole match in $1",
        "  !\\[",
        "      (.*?)           # alt text = $2",
        "  \\]",
        "  \\s?                # one optional whitespace character",
        "  \\(                 # literal paren",
        "      \\p{Z}*",
        "      (\(NotesTextProcessor.getNestedParensPattern()))    # href = $3",
        "      \\p{Z}*",
        "      (               # $4",
        "      (['\"])       # quote char = $5",
        "      (.*?)           # title = $6",
        "      \\5             # matching quote",
        "      \\p{Z}*",
        "      )?              # title is optional",
        "  \\)",
        ")"
        ].joined(separator: "\n")
    
    public static let imageInlineRegex = MarklightRegex(pattern: imageInlinePattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    // MARK: Code
    
    /*
     ```
     Code
     ```
     
     Code
     */
    
    public static let _codeBlockPattern = [
        "(                        # $1 = the code block -- one or more lines, starting with a space",
        "(?:",
        "    (?:\\p{Z}{4}|\\t+)       # Lines must start with a tab-width of spaces",
        "    .+(?:\\n+)",
        ")+",
        ")",
        "((?=^\\p{Z}{0,4}|\\t[^ \\t\\n])) # Lookahead for non-space at line-start, or end of doc"
        ].joined(separator: "\n")
    
    public static let _codeQuoteBlockPattern = [
        "(```[a-z]*\\n[\\s\\S]*?\\n```)"
        ].joined(separator: "\n")
            
    fileprivate static let codeSpanPattern = [
        "(?<![\\\\`])   # Character before opening ` can't be a backslash or backtick",
        "(`+)           # $1 = Opening run of `",
        "(?!`)          # and no more backticks -- match the full run",
        "(.+?)          # $2 = The code block",
        "(?<!`)",
        "\\1",
        "(?!`)"
        ].joined(separator: "\n")
    
    public static let codeSpanRegex = MarklightRegex(pattern: codeSpanPattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    fileprivate static let codeSpanOpeningPattern = [
        "(?<![\\\\`])   # Character before opening ` can't be a backslash or backtick",
        "(`+)           # $1 = Opening run of `"
        ].joined(separator: "\n")
    
    public static let codeSpanOpeningRegex = MarklightRegex(pattern: codeSpanOpeningPattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    fileprivate static let codeSpanClosingPattern = [
        "(?<![\\\\`])   # Character before opening ` can't be a backslash or backtick",
        "(`+)           # $1 = Opening run of `"
        ].joined(separator: "\n")
    
    public static let codeSpanClosingRegex = MarklightRegex(pattern: codeSpanClosingPattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    // MARK: Block quotes
    
    /*
     > Quoted text
     */
    
    fileprivate static let blockQuotePattern = [
        "(                           # Wrap whole match in $1",
        "    (",
        "    ^\\p{Z}*>\\p{Z}?              # '>' at the start of a line",
        "        .+(?:\\n|\\Z)               # rest of the first line",
        "    (.+(?:\\n|\\Z))*                # subsequent consecutive lines",
        "    (?:\\n|\\Z)*                    # blanks",
        "    )+",
        ")"
        ].joined(separator: "\n")
    
    public static let blockQuoteRegex = MarklightRegex(pattern: blockQuotePattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    fileprivate static let blockQuoteOpeningPattern = [
        "(^\\p{Z}*>\\p{Z})"
        ].joined(separator: "\n")
    
    public static let blockQuoteOpeningRegex = MarklightRegex(pattern: blockQuoteOpeningPattern, options: [.anchorsMatchLines])
    
    // MARK: Bold
    
    /*
     **Bold**
     __Bold__
     */
    
    fileprivate static let strictBoldPattern = "(^|[\\W_])(?:(?!\\1)|(?=^))(\\*|_)\\2(?=\\S)(.*?\\S)\\2\\2(?!\\2)(?=[\\W_]|$)"
    
    public static let strictBoldRegex = MarklightRegex(pattern: strictBoldPattern, options: [.anchorsMatchLines])
    
    fileprivate static let boldPattern = "(\\*\\*|__) (?=\\S) (.+?[*_]*) (?<=\\S) \\1"
    
    public static let boldRegex = MarklightRegex(pattern: boldPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    // MARK: Italic
    
    /*
     *Italic*
     _Italic_
     */
    
    fileprivate static let strictItalicPattern = "(^|[\\W_])(?:(?!\\1)|(?=^))(\\*|_)(?=\\S)((?:(?!\\2).)*?\\S)\\2(?!\\2)(?=[\\W_]|$)"
    
    public static let strictItalicRegex = MarklightRegex(pattern: strictItalicPattern, options: [.anchorsMatchLines])
    
    fileprivate static let italicPattern = "(\\*|_) (?=\\S) (.+?) (?<=\\S) \\1"
    
    public static let italicRegex = MarklightRegex(pattern: italicPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    fileprivate static let autolinkPattern = "((https?|ftp):[^'\">\\s]+)"
    
    public static let autolinkRegex = MarklightRegex(pattern: autolinkPattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    fileprivate static let autolinkPrefixPattern = "((https?|ftp)://)"
    
    public static let autolinkPrefixRegex = MarklightRegex(pattern: autolinkPrefixPattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    fileprivate static let autolinkEmailPattern = [
        "(?:mailto:)?",
        "(",
        "  [-.\\w]+",
        "  \\@",
        "  [-a-z0-9]+(\\.[-a-z0-9]+)*\\.[a-z]+",
        ")"
        ].joined(separator: "\n")
    
    public static let autolinkEmailRegex = MarklightRegex(pattern: autolinkEmailPattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    fileprivate static let mailtoPattern = "mailto:"
    
    public static let mailtoRegex = MarklightRegex(pattern: mailtoPattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
    
    /// maximum nested depth of [] and () supported by the transform;
    /// implementation detail
    fileprivate static let _nestDepth = 6
    
    fileprivate static var _nestedBracketsPattern = ""
    fileprivate static var _nestedParensPattern = ""
    
    /// Reusable pattern to match balanced [brackets]. See Friedl's
    /// "Mastering Regular Expressions", 2nd Ed., pp. 328-331.
    fileprivate static func getNestedBracketsPattern() -> String {
        // in other words [this] and [this[also]] and [this[also[too]]]
        // up to _nestDepth
        if (_nestedBracketsPattern.isEmpty) {
            _nestedBracketsPattern = repeatString([
                "(?>             # Atomic matching",
                "[^\\[\\]]+      # Anything other than brackets",
                "|",
                "\\["
                ].joined(separator: "\n"), _nestDepth) +
                repeatString(" \\])*", _nestDepth)
        }
        return _nestedBracketsPattern
    }
    
    /// Reusable pattern to match balanced (parens). See Friedl's
    /// "Mastering Regular Expressions", 2nd Ed., pp. 328-331.
    fileprivate static func getNestedParensPattern() -> String {
        // in other words (this) and (this(also)) and (this(also(too)))
        // up to _nestDepth
        if (_nestedParensPattern.isEmpty) {
            _nestedParensPattern = repeatString([
                "(?>            # Atomic matching",
                "[^()\\s]+      # Anything other than parens or whitespace",
                "|",
                "\\("
                ].joined(separator: "\n"), _nestDepth) +
                repeatString(" \\))*", _nestDepth)
        }
        return _nestedParensPattern
    }
    
    /// this is to emulate what's available in PHP
    fileprivate static func repeatString(_ text: String, _ count: Int) -> String {
        return Array(repeating: text, count: count).reduce("", +)
    }
    
    // We transform the user provided `codeFontName` `String` to a `NSFont`
    fileprivate static func codeFont(_ size: CGFloat) -> NSFont {
        if let font = UserDefaultsManagement.noteFont {
            return font
        } else {
            return NSFont.systemFont(ofSize: size)
        }
    }
    
    // We transform the user provided `quoteFontName` `String` to a `NSFont`
    fileprivate static func quoteFont(_ size: CGFloat) -> NSFont {
        if let font = UserDefaultsManagement.noteFont {
            return font
        } else {
            return NSFont.systemFont(ofSize: size)
        }
    }
}

public struct MarklightRegex {
    public let regularExpression: NSRegularExpression!
    
    public init(pattern: String, options: NSRegularExpression.Options = NSRegularExpression.Options(rawValue: 0)) {
        var error: NSError?
        let re: NSRegularExpression?
        do {
            re = try NSRegularExpression(pattern: pattern,
                                         options: options)
        } catch let error1 as NSError {
            error = error1
            re = nil
        }
        
        // If re is nil, it means NSRegularExpression didn't like
        // the pattern we gave it.  All regex patterns used by Markdown
        // should be valid, so this probably means that a pattern
        // valid for .NET Regex is not valid for NSRegularExpression.
        if re == nil {
            if let error = error {
                print("Regular expression error: \(error.userInfo)")
            }
            assert(re != nil)
        }
        
        self.regularExpression = re
    }
    
    public func matches(_ input: String, range: NSRange,
                        completion: @escaping (_ result: NSTextCheckingResult?) -> Void) {
        let s = input as NSString
        //NSRegularExpression.
        let options = NSRegularExpression.MatchingOptions(rawValue: 0)
        regularExpression.enumerateMatches(in: s as String,
                                           options: options,
                                           range: range,
                                           using: { (result, flags, stop) -> Void in

                                            completion(result)
        })
    }
}

public extension NSImage {
    public func imageRotatedByDegreess(degrees:CGFloat) -> NSImage {
        
        var imageBounds = NSZeroRect ; imageBounds.size = self.size
        let pathBounds = NSBezierPath(rect: imageBounds)
        var transform = NSAffineTransform()
        transform.rotate(byDegrees: degrees)
        pathBounds.transform(using: transform as AffineTransform)
        let rotatedBounds:NSRect = NSMakeRect(NSZeroPoint.x, NSZeroPoint.y , self.size.width, self.size.height )
        let rotatedImage = NSImage(size: rotatedBounds.size)
        
        //Center the image within the rotated bounds
        imageBounds.origin.x = NSMidX(rotatedBounds) - (NSWidth(imageBounds) / 2)
        imageBounds.origin.y  = NSMidY(rotatedBounds) - (NSHeight(imageBounds) / 2)
        
        // Start a new transform
        transform = NSAffineTransform()
        // Move coordinate system to the center (since we want to rotate around the center)
        transform.translateX(by: +(NSWidth(rotatedBounds) / 2 ), yBy: +(NSHeight(rotatedBounds) / 2))
        transform.rotate(byDegrees: degrees)
        // Move the coordinate system bak to normal
        transform.translateX(by: -(NSWidth(rotatedBounds) / 2 ), yBy: -(NSHeight(rotatedBounds) / 2))
        // Draw the original image, rotated, into the new image
        rotatedImage.lockFocus()
        transform.concat()
        self.draw(in: imageBounds, from: NSZeroRect, operation: .copy, fraction: 1.0)
        rotatedImage.unlockFocus()
        
        return rotatedImage
    }
}
