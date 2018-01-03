//
//  NotesTextStorage.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 12/26/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Marklight
import Highlightr

public class NotesTextStorage: NSTextStorage, MarklightStyleApplier {
    // MARK: Syntax highlight customisation
    
    /**
     Color used to highlight markdown syntax. Default value is light grey.
     */
    open var syntaxColor = NSColor.lightGray
    
    /**
     Font used for blocks and inline code. Default value is *Menlo*.
     */
    open var codeFontName = "Menlo"
    
    /**
     `MarklightColor` used for blocks and inline code. Default value is dark grey.
     */
    open var codeColor = NSColor.darkGray
    
    /**
     Font used for quote blocks. Default value is *Menlo*.
     */
    open var quoteFontName = "Menlo"
    
    /**
     `MarklightColor` used for quote blocks. Default value is dark grey.
     */
    open var quoteColor = NSColor.darkGray
    
    /**
     Quote indentation in points. Default 20.
     */
    open var quoteIndendation : CGFloat = 20
    
    var codeFont = NSFont(name: "Source Code Pro", size: CGFloat(UserDefaultsManagement.fontSize))
    
    /**
     If the markdown syntax should be hidden or visible
     */
    open var hideSyntax = false
    
    var storage = NSMutableAttributedString(string: "")
    
    override init() {
        super.init()
    }
    
    required public init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func processEditing() {
        if editedMask.contains(.editedCharacters) {
            let string = (self.string as NSString)
            let range = string.paragraphRange(for: editedRange)
            
            // code highlighting
            if NotesTextStorage.isCodeBlockParagraph(string.substring(with: range)) && UserDefaultsManagement.codeBlockHighlight {
                if let codeBlockRange = findCodeBlockRange(string: string, lineRange: range) {
                    highlightCode(range: codeBlockRange)
                }
            } else {
                storage.fixAttributes(in: range)
                NotesTextStorage.applyMarkdownStyle(
                    storage,
                    string: storage.string,
                    affectedRange: range
                )
            }
        }
        
        super.processEditing()
    }
        
    public static func isCodeBlockParagraph(_ paragraph: String) -> Bool {
        return (paragraph.starts(with: "\t") || paragraph.starts(with: "    "))
    }
    
    func findCodeBlockRange(string: NSString, lineRange: NSRange) -> NSRange? {
        let firstParagraphRange = string.paragraphRange(for: NSRange(location: lineRange.location, length: 0))
        
        if string.substring(with: firstParagraphRange).starts(with: "```") {
            let fencedBlockEnd = scanBackQuoteEnd(string: string, location: firstParagraphRange.upperBound + 1)
            return NSRange(lineRange.location..<fencedBlockEnd)
        }
        
        let start = scanPrevParagraph(string: string, location: firstParagraphRange.lowerBound - 1)!
        let end = scanNextParagraph(string: string, location: firstParagraphRange.upperBound + 1)!
        return NSRange(start..<end)
    }
    
    func scanBackQuoteEnd(string: NSString, location: Int) -> Int {
        guard location < string.length else {
            return location - 1
        }
        
        let range = string.paragraphRange(for: NSRange(location: location, length: 0))
        let substring = string.substring(with: range)
        if substring.starts(with: "```") {
            return location + 3
        }
        
        return scanBackQuoteEnd(string: string, location: range.upperBound + 1)
    }
    
    func scanPrevParagraph(string: NSString, location: Int) -> Int? {
        guard location > 0 else {
            return location + 1
        }
        
        let range = string.paragraphRange(for: NSRange(location: location, length: 0))
        let substring = string.substring(with: range)
        if NotesTextStorage.isCodeBlockParagraph(substring) {
            return scanPrevParagraph(string: string, location: range.lowerBound - 1)
        }
        
        return location + 1
    }
    
    func scanNextParagraph(string: NSString, location: Int) -> Int? {
        guard location < string.length + 1 else {
            return location - 1
        }
    
        let range = string.paragraphRange(for: NSRange(location: location, length: 0))
        let substring = string.substring(with: range)
        if NotesTextStorage.isCodeBlockParagraph(substring) {
            return scanNextParagraph(string: string, location: range.upperBound + 1)
        }
        
        return location - 1
    }
    
    open override var string: String {
        get {
            return storage.string
        }
    }
    
    open override func replaceCharacters(in range: NSRange, with str: String) {
        storage.replaceCharacters(in: range, with: str)
        self.edited(NSTextStorageEditActions.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
    }
    
    open override func setAttributes(_ attrs: [NSAttributedStringKey : Any]?, range: NSRange) {
        storage.setAttributes(attrs, range: range)
        self.edited(NSTextStorageEditActions.editedAttributes, range: range, changeInLength: 0)
    }
    
    override public func addAttributes(_ attrs: [NSAttributedStringKey : Any] = [:], range: NSRange) {
        storage.addAttributes(attrs, range: range)
        self.edited(NSTextStorageEditActions.editedAttributes, range: range, changeInLength: 0)
    }
    
    open override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedStringKey : Any] {
        return storage.attributes(at: location, effectiveRange: range)
    }
    
    public func resetMarklightTextAttributes(textSize: CGFloat, range: NSRange) {
        storage.removeAttribute(NSAttributedStringKey.foregroundColor, range: range)
        storage.addAttribute(NSAttributedStringKey.font, value: MarklightFont.systemFont(ofSize: textSize), range: range)
        storage.addAttribute(NSAttributedStringKey.paragraphStyle, value: NSParagraphStyle(), range: range)
    }
    
    func highlightCode(range: NSRange) {
        let string = (self.string as NSString)
        let line = string.substring(with: range)

        DispatchQueue.global().async {
            guard let highlightr = Highlightr() else {
                return
            }
            
            highlightr.setTheme(to: "github")
            let tmpStrg = highlightr.highlight(line)
            DispatchQueue.main.async(execute: {
                if((range.location + range.length) > self.storage.length) {
                    return
                }
                
                if(tmpStrg?.string != self.storage.attributedSubstring(from: range).string) {
                    return
                }
                
                self.beginEditing()
                tmpStrg?.enumerateAttributes(in: NSMakeRange(0, (tmpStrg?.length)!), options: [], using: { (attrs, locRange, stop) in
                    var fixedRange = NSMakeRange(range.location+locRange.location, locRange.length)
                    fixedRange.length = (fixedRange.location + fixedRange.length < string.length) ? fixedRange.length : string.length-fixedRange.location
                    fixedRange.length = (fixedRange.length >= 0) ? fixedRange.length : 0
                    self.storage.setAttributes(attrs, range: fixedRange)
                    if let font = self.codeFont {
                        self.storage.addAttributes([.font: font], range: range)
                    }
                })
                self.endEditing()
                self.edited(NSTextStorageEditActions.editedAttributes, range: range, changeInLength: 0)

                self.storage.addAttributes([
                    .backgroundColor: NSColor(red:0.97, green:0.97, blue:0.97, alpha:1.0)
                    ], range: range)
            })
        }
    }
    
    fileprivate static var quoteIndendationStyle : NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = CGFloat(20)
        return paragraphStyle
    }
    
    public static func applyMarkdownStyle(_ styleApplier: NSMutableAttributedString, string: String, affectedRange paragraphRange: NSRange) {
        let textStorageNSString = string as NSString
        let wholeRange = NSMakeRange(0, textStorageNSString.length)
        
        let codeFont = NotesTextStorage.codeFont(CGFloat(UserDefaultsManagement.fontSize))
        let quoteFont = NotesTextStorage.quoteFont(CGFloat(UserDefaultsManagement.fontSize))
        let boldFont = MarklightFont.boldSystemFont(ofSize: CGFloat(UserDefaultsManagement.fontSize))
        let italicFont = MarklightFont.italicSystemFont(ofSize: CGFloat(UserDefaultsManagement.fontSize))
        
        let hiddenFont = MarklightFont.systemFont(ofSize: 0.1)
        let hiddenColor = MarklightColor.clear
        let hiddenAttributes: [NSAttributedStringKey : Any] = [
            .font : hiddenFont,
            .foregroundColor : hiddenColor
        ]
        
        func hideSyntaxIfNecessary(range: @autoclosure () -> NSRange) {
            guard Marklight.hideSyntax else { return }
            
            styleApplier.addAttributes(hiddenAttributes, range: range())
        }
        
        // We detect and process underlined headers
        Marklight.headersSetextRegex.matches(string, range: wholeRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: boldFont, range: range)
            Marklight.headersSetextUnderlineRegex.matches(string, range: paragraphRange) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: NSMakeRange(innerRange.location, innerRange.length))
            }
        }
        
        // We detect and process dashed headers
        Marklight.headersAtxRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: boldFont, range: range)
            Marklight.headersAtxOpeningRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                let syntaxRange = NSMakeRange(innerRange.location, innerRange.length + 1)
                hideSyntaxIfNecessary(range: syntaxRange)
            }
            Marklight.headersAtxClosingRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: innerRange)
            }
        }
        
        // We detect and process reference links
        Marklight.referenceLinkRegex.matches(string, range: wholeRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: range)
        }
        
        // We detect and process lists
        Marklight.listRegex.matches(string, range: wholeRange) { (result) -> Void in
            guard let range = result?.range else { return }
            Marklight.listOpeningRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
            }
        }
        
        // We detect and process anchors (links)
        Marklight.anchorRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: codeFont, range: range)
            Marklight.openingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
            }
            Marklight.closingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
            }
            Marklight.parenRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                let initialSyntaxRange = NSMakeRange(innerRange.location, 1)
                let finalSyntaxRange = NSMakeRange(innerRange.location + innerRange.length - 1, 1)
                hideSyntaxIfNecessary(range: initialSyntaxRange)
                hideSyntaxIfNecessary(range: finalSyntaxRange)
            }
        }
        
        // We detect and process inline anchors (links)
        Marklight.anchorInlineRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: codeFont, range: range)
            
            var destinationLink : String?
            
            Marklight.coupleRoundRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                
                var _range = innerRange
                _range.location = range.location + 1
                _range.length = range.length - 2
                
                let substring = textStorageNSString.substring(with: _range)
                guard substring.lengthOfBytes(using: .utf8) > 0 else { return }
                
                destinationLink = substring
                styleApplier.addAttribute(.link, value: substring, range: _range)
                
                hideSyntaxIfNecessary(range: innerRange)
            }
            
            Marklight.openingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: innerRange)
            }
            
            Marklight.closingSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: innerRange)
            }
            
            guard let destinationLinkString = destinationLink else { return }
            
            Marklight.coupleSquareRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                var _range = innerRange
                _range.location = _range.location + 1
                _range.length = _range.length - 2
                
                let substring = textStorageNSString.substring(with: _range)
                guard substring.lengthOfBytes(using: .utf8) > 0 else { return }
                
                styleApplier.addAttribute(.link, value: destinationLinkString, range: _range)
            }
        }
        
        Marklight.imageRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: codeFont, range: range)
            
            // TODO: add image attachment
            if Marklight.hideSyntax {
                styleApplier.addAttribute(.font, value: hiddenFont, range: range)
            }
            Marklight.imageOpeningSquareRegex.matches(string, range: paragraphRange) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
            }
            Marklight.imageClosingSquareRegex.matches(string, range: paragraphRange) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
            }
        }
        
        // We detect and process inline images
        Marklight.imageInlineRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            
            styleApplier.addAttribute(.font, value: codeFont, range: range)
            
            // TODO: add image attachment
            
            hideSyntaxIfNecessary(range: range)
            
            Marklight.imageOpeningSquareRegex.matches(string, range: paragraphRange) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                // FIXME: remove syntax and add image
            }
            Marklight.imageClosingSquareRegex.matches(string, range: paragraphRange) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                // FIXME: remove syntax and add image
            }
            Marklight.parenRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                // FIXME: remove syntax and add image
            }
        }
        
        // We detect and process quotes
        Marklight.blockQuoteRegex.matches(string, range: wholeRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: quoteFont, range: range)
            styleApplier.addAttribute(.foregroundColor, value: NSColor.darkGray, range: range)
            styleApplier.addAttribute(.paragraphStyle, value: quoteIndendationStyle, range: range)
            Marklight.blockQuoteOpeningRegex.matches(string, range: range) { (innerResult) -> Void in
                guard let innerRange = innerResult?.range else { return }
                styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: innerRange)
                hideSyntaxIfNecessary(range: innerRange)
            }
        }
        
        // We detect and process strict italics
        Marklight.strictItalicRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: italicFont, range: range)
            let substring = textStorageNSString.substring(with: NSMakeRange(range.location, 1))
            var start = 0
            if substring == " " {
                start = 1
            }
            
            let preRange = NSMakeRange(range.location + start, 1)
            hideSyntaxIfNecessary(range: preRange)
            styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: preRange)
            
            let postRange = NSMakeRange(range.location + range.length - 1, 1)
            styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: postRange)
            hideSyntaxIfNecessary(range: postRange)
        }
        
        // We detect and process strict bolds
        Marklight.strictBoldRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: boldFont, range: range)
            let substring = textStorageNSString.substring(with: NSMakeRange(range.location, 1))
            var start = 0
            if substring == " " {
                start = 1
            }
            
            let preRange = NSMakeRange(range.location + start, 2)
            styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: preRange)
            hideSyntaxIfNecessary(range: preRange)
            
            let postRange = NSMakeRange(range.location + range.length - 2, 2)
            styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: postRange)
            hideSyntaxIfNecessary(range: postRange)
        }
        
        // We detect and process italics
        Marklight.italicRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: italicFont, range: range)
            
            let preRange = NSMakeRange(range.location, 1)
            styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: preRange)
            hideSyntaxIfNecessary(range: preRange)
            
            let postRange = NSMakeRange(range.location + range.length - 1, 1)
            styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: postRange)
            hideSyntaxIfNecessary(range: postRange)
        }
        
        // We detect and process bolds
        Marklight.boldRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            styleApplier.addAttribute(.font, value: boldFont, range: range)
            
            let preRange = NSMakeRange(range.location, 2)
            styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: preRange)
            hideSyntaxIfNecessary(range: preRange)
            
            let postRange = NSMakeRange(range.location + range.length - 2, 2)
            styleApplier.addAttribute(.foregroundColor, value: Marklight.syntaxColor, range: postRange)
            hideSyntaxIfNecessary(range: postRange)
        }
        
        // We detect and process inline links not formatted
        Marklight.autolinkRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            let substring = textStorageNSString.substring(with: range)
            guard substring.lengthOfBytes(using: .utf8) > 0 else { return }
            styleApplier.addAttribute(.link, value: substring, range: range)
            
            if Marklight.hideSyntax {
                Marklight.autolinkPrefixRegex.matches(string, range: range) { (innerResult) -> Void in
                    guard let innerRange = innerResult?.range else { return }
                    styleApplier.addAttribute(.font, value: hiddenFont, range: innerRange)
                    styleApplier.addAttribute(.foregroundColor, value: hiddenColor, range: innerRange)
                }
            }
        }
        
        // We detect and process inline mailto links not formatted
        Marklight.autolinkEmailRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard let range = result?.range else { return }
            let substring = textStorageNSString.substring(with: range)
            guard substring.lengthOfBytes(using: .utf8) > 0 else { return }
            styleApplier.addAttribute(.link, value: substring, range: range)
            
            if Marklight.hideSyntax {
                Marklight.mailtoRegex.matches(string, range: range) { (innerResult) -> Void in
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
        "\\n+"
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
        "\\n+"
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
        "        (\(NotesTextStorage.getNestedBracketsPattern()))  # link text = $2",
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
        "      (\(NotesTextStorage.getNestedParensPattern()))    # href = $3",
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
        "        (\(NotesTextStorage.getNestedBracketsPattern()))   # link text = $2",
        "    \\]",
        "    \\(                     # literal paren",
        "        \\p{Z}*",
        "        (\(NotesTextStorage.getNestedParensPattern()))   # href = $3",
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
        "      (\(NotesTextStorage.getNestedParensPattern()))    # href = $3",
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
    
    fileprivate static let codeBlockPattern = [
        "(?:\\n\\n|\\A\\n?)",
        "(                        # $1 = the code block -- one or more lines, starting with a space",
        "(?:",
        "    (?:\\p{Z}{\(_tabWidth)})       # Lines must start with a tab-width of spaces",
        "    .*\\n+",
        ")+",
        ")",
        "((?=^\\p{Z}{0,\(_tabWidth)}[^ \\t\\n])|\\Z) # Lookahead for non-space at line-start, or end of doc"
        ].joined(separator: "\n")
    
    public static let codeBlockRegex = MarklightRegex(pattern: codeBlockPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])
    
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
        "        .+\\n               # rest of the first line",
        "    (.+\\n)*                # subsequent consecutive lines",
        "    \\n*                    # blanks",
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
    fileprivate static func codeFont(_ size: CGFloat) -> MarklightFont {
        if let font = UserDefaultsManagement.noteFont {
            return font
        } else {
            return MarklightFont.systemFont(ofSize: size)
        }
    }
    
    // We transform the user provided `quoteFontName` `String` to a `NSFont`
    fileprivate static func quoteFont(_ size: CGFloat) -> MarklightFont {
        if let font = MarklightFont(name: Marklight.quoteFontName, size: size) {
            return font
        } else {
            return MarklightFont.systemFont(ofSize: size)
        }
    }
}



#if os(iOS)
    import UIKit
    
    typealias MarklightColor = UIColor
    typealias MarklightFont = UIFont
    typealias MarklightFontDescriptor = UIFontDescriptor
#elseif os(macOS)
    import AppKit
    
    
    typealias MarklightColor = NSColor
    typealias MarklightFont = NSFont
    typealias MarklightFontDescriptor = NSFontDescriptor
    
    extension NSFont {
        static func italicSystemFont(ofSize size: CGFloat) -> NSFont {
            return NSFontManager().convert(NSFont.systemFont(ofSize: size), toHaveTrait: .italicFontMask)
        }
    }
#endif
