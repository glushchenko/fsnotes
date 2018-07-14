//
//  NotesTextStorage.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 12/26/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Highlightr

#if os(OSX)
    import Cocoa
    import MASShortcut
#else
    import UIKit
    import NightNight
#endif

public class NotesTextProcessor {
#if os(OSX)
    typealias Color = NSColor
    typealias Image = NSImage
    typealias Font = NSFont
#else
    typealias Color = UIColor
    typealias Image = UIImage
    typealias Font = UIFont
#endif
    // MARK: Syntax highlight customisation
    
    /**
     Color used to highlight markdown syntax. Default value is light grey.
     */
    open static var syntaxColor = Color.lightGray
    
#if os(OSX)
    open static var codeBackground = NSColor(red:0.97, green:0.97, blue:0.97, alpha:1.0)
    open var highlightColor = NSColor(red:1.00, green:0.90, blue:0.70, alpha:1.0)
#else
    open static var codeBackground: UIColor {
        get {
            if NightNight.theme == .night {
                return UIColor(red:0.27, green:0.27, blue:0.27, alpha:1.0)
            } else {
                return UIColor(red:0.94, green:0.95, blue:0.95, alpha:1.0)
            }
        }
    }
    open var highlightColor = UIColor(red:1.00, green:0.90, blue:0.70, alpha:1.0)
#endif
    
    /**
     Quote indentation in points. Default 20.
     */
    open var quoteIndendation : CGFloat = 20
    
#if os(OSX)
    public static var codeFont = NSFont(name: "Source Code Pro", size: CGFloat(UserDefaultsManagement.fontSize))
#else
    static var codeFont: UIFont? {
        get {
            if var font = UIFont(name: "Source Code Pro", size: CGFloat(UserDefaultsManagement.fontSize)) {
    
                if #available(iOS 11.0, *) {
                    let fontMetrics = UIFontMetrics(forTextStyle: .body)
                    font = fontMetrics.scaledFont(for: font)
                }
    
                return font
            }
    
            return nil
        }
    }
#endif
    
    /**
     If the markdown syntax should be hidden or visible
     */
    open static var hideSyntax = false
    
    private var note: Note?
    private var storage: NSTextStorage?
    private var range: NSRange?
    private var width: CGFloat?
    
    init(note: Note? = nil, storage: NSTextStorage? = nil, range: NSRange? = nil, maxWidth: CGFloat? = nil) {
        self.note = note
        self.storage = storage
        self.range = range
        self.width = maxWidth
    }
    
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
        
        guard UserDefaultsManagement.codeBlockHighlight else {
            return
        }
        
        let content = storage != nil ? storage! : note.content
        let range = NSMakeRange(0, content.length)
        
        let regex = try! NSRegularExpression(pattern: self._codeBlockPattern, options: [
            .allowCommentsAndWhitespace,
            .anchorsMatchLines
        ])
        
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
                
                if let codeBlockRange = NotesTextProcessor.getCodeBlockRange(paragraphRange: paragraphRange, string: string),
                    codeBlockRange.upperBound <= content.length {
                    
                    NotesTextProcessor.highlightCode(range: codeBlockRange, storage: storage, string: string, note: note, async: async)
                }
            }
        )
    
        let regexFencedCodeBlock = try! NSRegularExpression(pattern: self._codeQuoteBlockPattern, options: [
            .allowCommentsAndWhitespace,
            .anchorsMatchLines
            ])
    
        regexFencedCodeBlock.enumerateMatches(
            in: content.string,
            options: NSRegularExpression.MatchingOptions(),
            range: range,
            using: { (result, matchingFlags, stop) -> Void in
                guard let r = result else {
                    return
                }
                let string = (content.string as NSString)
                let paragraphRange = string.paragraphRange(for: r.range)
                
                if let fencedCodeBlockRange = NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: paragraphRange, string: string),
                    fencedCodeBlockRange.upperBound <= content.length {
                    
                    NotesTextProcessor.highlightCode(range: fencedCodeBlockRange, storage: storage, string: string, note: note, async: async)
                }
            }
        )
    }
    
    public static func scanBasicSyntax(note: Note, storage: NSTextStorage? = nil, range: NSRange? = nil) {
        var affectedRange: NSRange
        
        if let r = range {
            affectedRange = r
        } else {
            affectedRange = NSRange(0..<note.content.length)
        }
        
        let target = storage != nil ? storage! : note.content
        
        self.scanMarkdownSyntax(target, paragraphRange: affectedRange, note: note)
    }
    
    public static func highlight(_ code: String, language: String? = nil) -> NSAttributedString? {
        if let highlighter = NotesTextProcessor.getHighlighter() {
            if let result = highlighter.highlight(code, as: language) {
                return result
            }
        }
        return nil
    }
    
    #if os(iOS)
    public static func updateFont(note: Note) {
        if var font = UserDefaultsManagement.noteFont {
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font)
            }
        
            note.content.addAttribute(.font, value: font, range: NSRange(0..<note.content.length))
        }
    }
    #endif
    
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
        
        var isActiveStorage = false
        #if os(iOS)
            isActiveStorage = true
        #else
            if let n = EditTextView.note {
                isActiveStorage = (n === note)
            }
        #endif
        
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
                
                if note.content.length >= fixedRange.location + fixedRange.length {
                    note.content.setAttributes(attrs, range: fixedRange)
                }
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
                .backgroundColor: NotesTextProcessor.codeBackground
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
                        let codeM = NotesTextProcessor.updateParagraphStyle(code: code)
                        NotesTextProcessor.updateStorage(range: range, code: codeM, storage: storage, string: string, note: note)
                    })
                }
            }
            
            return
        }
            
        if let code = NotesTextProcessor.highlight(codeRange, language: preDefinedLanguage) {
            let codeM = NotesTextProcessor.updateParagraphStyle(code: code)
            NotesTextProcessor.updateStorage(range: range, code: codeM, storage: storage, string: string, note: note)
        }
    }
    
    public static func updateParagraphStyle(code: NSAttributedString) -> NSMutableAttributedString {
        let codeM = NSMutableAttributedString(attributedString: code)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        codeM.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(0..<codeM.length))
        return codeM
    }
    
    fileprivate static var quoteIndendationStyle : NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        return paragraphStyle
    }
    
    public static var languages: [String]? = nil
    
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
    
    public static func scanMarkdownSyntax(_ styleApplier: NSMutableAttributedString, paragraphRange: NSRange, note: Note, textChanged: Bool = false) {
        let isFullScan = styleApplier.length == paragraphRange.upperBound && paragraphRange.lowerBound == 0
        
        let textStorageNSString = styleApplier.string as NSString
        let string = styleApplier.string
        
        let codeFont = NotesTextProcessor.codeFont(CGFloat(UserDefaultsManagement.fontSize))
        let quoteFont = NotesTextProcessor.quoteFont(CGFloat(UserDefaultsManagement.fontSize))
        
    #if os(OSX)
        let boldFont = NSFont.boldFont()
        let italicFont = NSFont.italicFont()
        let hiddenFont = NSFont.systemFont(ofSize: 0.1)
    #else
        var boldFont: UIFont {
            get {
                var font = UserDefaultsManagement.noteFont.bold()
                font.withSize(CGFloat(UserDefaultsManagement.fontSize))
                
                if #available(iOS 11.0, *) {
                    let fontMetrics = UIFontMetrics(forTextStyle: .body)
                    font = fontMetrics.scaledFont(for: font)
                }
                
                return font
            }
        }
        
        var italicFont: UIFont {
            get {
                var font = UserDefaultsManagement.noteFont.italic()
                font.withSize(CGFloat(UserDefaultsManagement.fontSize))
                
                if #available(iOS 11.0, *) {
                    let fontMetrics = UIFontMetrics(forTextStyle: .body)
                    font = fontMetrics.scaledFont(for: font)
                }
                
                return font
            }
        }
        
        let hiddenFont = UIFont.systemFont(ofSize: 0.1)
    #endif
        
        let hiddenColor = Color.clear
        let hiddenAttributes: [NSAttributedStringKey : Any] = [
            .font : hiddenFont,
            .foregroundColor : hiddenColor
        ]
        
        func hideSyntaxIfNecessary(range: @autoclosure () -> NSRange) {
            guard NotesTextProcessor.hideSyntax else { return }
            
            styleApplier.addAttributes(hiddenAttributes, range: range())
        }
        
        styleApplier.removeAttribute(.link, range: paragraphRange)
        styleApplier.removeAttribute(.backgroundColor, range: paragraphRange)
        
        #if os(OSX)
            if let font = UserDefaultsManagement.noteFont,
                isFullScan || textChanged {
                styleApplier.addAttribute(.font, value: font, range: paragraphRange)
            }
        #endif
        
        #if os(iOS)
            if NightNight.theme == .night {
                styleApplier.addAttribute(.foregroundColor, value: UIColor.white, range: paragraphRange)
            } else {
                styleApplier.addAttribute(.foregroundColor, value: UserDefaultsManagement.fontColor, range: paragraphRange)
            }
        #else
            styleApplier.addAttribute(.foregroundColor, value: UserDefaultsManagement.fontColor, range: paragraphRange)
        #endif

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
            NotesTextProcessor.headersSetextUnderlineRegex.matches(string, range: range) { (innerResult) -> Void in
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
                
                var mdTitleLength = 0
                let mdLink = textStorageNSString.substring(with: innerRange)
                
                if let match = mdLink.range(of: "\\[(.+)\\]", options: .regularExpression) {
                    mdTitleLength = mdLink[match].count - 2
                }
                
                var _range = innerRange
                _range.location = range.location + 3 + mdTitleLength
                _range.length = range.length - 4 - mdTitleLength
                
                var substring = textStorageNSString.substring(with: _range)
                guard substring.lengthOfBytes(using: .utf8) > 0 else { return }
                
                if substring.starts(with: "/i/"), let project = note.project, let path = project.url.appendingPathComponent(substring).path.removingPercentEncoding {
                    substring = "file://" + path
                }
                
                if note.type == .TextBundle && substring.starts(with: "assets/"), let path = note.url.appendingPathComponent(substring).path.removingPercentEncoding {
                    substring = "file://" + path
                }
                
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
        
        // We detect and process app urls [[link]]
        NotesTextProcessor.appUrlRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let innerRange = result?.range else { return }
            var _range = innerRange
            _range.location = _range.location + 2
            _range.length = _range.length - 4
            
            let appLink = textStorageNSString.substring(with: _range)
            styleApplier.addAttribute(.link, value: "fsnotes://find/" + appLink, range: innerRange)
        }
        
        // We detect and process quotes
        NotesTextProcessor.blockQuoteRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: quoteFont, range: range)
            styleApplier.addAttribute(.foregroundColor, value: Color.darkGray, range: range)
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
        "\\n|\\Z"
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
        "(?:\\n|\\Z)"
        ].joined(separator: "\n")
    
    public static let headersAtxRegex = MarklightRegex(pattern: headerAtxPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    fileprivate static let headersAtxOpeningPattern = [
        "^(\\#{1,6})"
        ].joined(separator: "\n")
    
    public static let headersAtxOpeningRegex = MarklightRegex(pattern: headersAtxOpeningPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
    fileprivate static let headersAtxClosingPattern = [
        "\\#{1,6}\\n+"
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
        "(?:\\n|\\Z)"
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
        ".*(?:\\])\\((.+)\\)"
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
        "(",
        "   (?:",
        "       (?:\\p{Z}{4}|\\t+)              # Lines must start with a tab-width of spaces",
        "       .+(?:\\n+)",
        "   )+",
        ")",
        "(?=^\\p{Z}{0,4}|\\t[^ \\t\\n])|(?=\\Z) # Lookahead for non-space at line-start, or end of doc"
        ].joined(separator: "\n")
    
    public static let _codeQuoteBlockPattern = [
        "(^```[a-zA-Z0-9]*\\n[\\s\\S]*?\\n```)"
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
    
    // MARK: App url
    
    fileprivate static let appUrlPattern = "(\\[\\[)(.+?[\\[\\]]*)\\]\\]"
    
    public static let appUrlRegex = MarklightRegex(pattern: appUrlPattern, options: [.anchorsMatchLines])
    
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
    
    fileprivate static let autolinkPattern = "((https?|ftp):[^\\)'\">\\s]+)"
    
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
    fileprivate static func codeFont(_ size: CGFloat) -> Font {
        if var font = UserDefaultsManagement.noteFont {
            #if os(iOS)
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font)
            }
            #endif
            
            return font
        } else {
        #if os(OSX)
            return NSFont.systemFont(ofSize: size)
        #else
            return UIFont.systemFont(ofSize: size)
        #endif
        }
    }
    
    // We transform the user provided `quoteFontName` `String` to a `NSFont`
    fileprivate static func quoteFont(_ size: CGFloat) -> Font {
        if var font = UserDefaultsManagement.noteFont {
            #if os(iOS)
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font)
            }
            #endif
            
            return font
        } else {
        #if os(OSX)
            return NSFont.systemFont(ofSize: size)
        #else
            return UIFont.systemFont(ofSize: size)
        #endif
        }
    }
    
    public func higlightLinks() {
        guard let storage = self.storage, let range = self.range else {
            return
        }
        
        storage.removeAttribute(.link, range: range)
        
        let pattern = "(https?:\\/\\/(?:www\\.|(?!www))[^\\s\\.]+\\.[^\\s]{2,}|www\\.[^\\s]+\\.[^\\s]{2,})"
        let regex = try! NSRegularExpression(pattern: pattern, options: [NSRegularExpression.Options.caseInsensitive])
        
        regex.enumerateMatches(
            in: (storage.string),
            options: NSRegularExpression.MatchingOptions(),
            range: range,
            using: { (result, matchingFlags, stop) -> Void in
                if let range = result?.range {
                    guard storage.length > range.location + range.length else {
                        return
                    }
                    
                    var str = storage.mutableString.substring(with: range)
                    
                    if str.starts(with: "www.") {
                        str = "http://" + str
                    }
                    
                    guard let url = URL(string: str) else {
                        return
                    }
                    
                    storage.addAttribute(.link, value: url, range: range)
                }
            }
        )
        
        // We detect and process app urls [[link]]
        NotesTextProcessor.appUrlRegex.matches(storage.string, range: range) { (result) -> Void in
            guard let innerRange = result?.range else { return }
            let from = String.Index.init(encodedOffset: innerRange.lowerBound + 2)
            let to = String.Index.init(encodedOffset: innerRange.upperBound - 2)
            
            let appLink = storage.string[from..<to]
            storage.addAttribute(.link, value: "fsnotes://find/" + appLink, range: innerRange)
        }
    }
    
    public func scanParagraph(textChanged: Bool = false) {
        guard let note = self.note, let storage = self.storage, let range = self.range, let maxWidth = self.width else {
            return
        }
        
        guard (storage.length >= range.location + range.length) || textChanged else { return }
     
        let string = storage.string as NSString
        var paragraphRange = string.paragraphRange(for: range)
        let currentString = string.substring(with: paragraphRange)
        
        // Proper paragraph scan for two line markup "==" and "--"
        let prevParagraphLocation = paragraphRange.lowerBound - 1
        if prevParagraphLocation > 0 && (currentString.starts(with: "==") || currentString.starts(with: "--")) {
            let prev = string.paragraphRange(for: NSRange(location: prevParagraphLocation, length: 0))
            paragraphRange = NSRange(location: prev.lowerBound, length: paragraphRange.upperBound - prev.lowerBound)
        }

        if UserDefaultsManagement.codeBlockHighlight, let fencedRange = NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: paragraphRange, string: string) {
                NotesTextProcessor.highlightCode(range: fencedRange, storage: storage, string: string, note: note)
        } else if UserDefaultsManagement.codeBlockHighlight, let codeBlockRange = NotesTextProcessor.getCodeBlockRange(paragraphRange: paragraphRange, string: string) {
                NotesTextProcessor.highlightCode(range: codeBlockRange, storage: storage, string: string, note: note)
        } else {
            NotesTextProcessor.scanMarkdownSyntax(storage, paragraphRange: paragraphRange, note: note, textChanged: true)
            
            if UserDefaultsManagement.liveImagesPreview {
                let processor = ImagesProcessor(styleApplier: storage, range: paragraphRange, maxWidth: maxWidth, note: note)
                processor.load()
            }
        }
    }
    
    func highlightKeyword(search: String = "", remove: Bool = false) {
        guard let storage = self.storage else {
            return
        }
        
        guard search.count > 0 else {
            return
        }
        
        let searchTerm = NSRegularExpression.escapedPattern(for: search)
        let attributedString: NSMutableAttributedString = NSMutableAttributedString(attributedString: storage)
        let pattern = "(\(searchTerm))"
        let range: NSRange = NSMakeRange(0, storage.string.count)
                
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [NSRegularExpression.Options.caseInsensitive])
            
            regex.enumerateMatches(
                in: storage.string,
                options: NSRegularExpression.MatchingOptions(),
                range: range,
                using: {
                    (textCheckingResult, matchingFlags, stop) -> Void in
                    guard let subRange = textCheckingResult?.range else {
                        return
                    }
                    
                    if remove {
                        if attributedString.attributes(at: subRange.location, effectiveRange: nil).keys.contains(NoteAttribute.highlight) {
                            attributedString.removeAttribute(NoteAttribute.highlight, range: subRange)
                            attributedString.addAttribute(NSAttributedStringKey.backgroundColor, value: NotesTextProcessor.codeBackground, range: subRange)
                        } else {
                            attributedString.removeAttribute(NSAttributedStringKey.backgroundColor, range: subRange)
                        }
                    } else {
                        if attributedString.attributes(at: subRange.location, effectiveRange: nil).keys.contains(NSAttributedStringKey.backgroundColor) {
                            attributedString.addAttribute(NoteAttribute.highlight, value: true, range: subRange)
                        }
                        attributedString.addAttribute(NSAttributedStringKey.backgroundColor, value: highlightColor, range: subRange)
                    }
            }
            )
            
            storage.setAttributedString(attributedString)
        } catch {}
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
