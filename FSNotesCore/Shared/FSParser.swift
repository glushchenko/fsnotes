//
//  FSParser.swift
//  FSNotes
//
//  Created by Александр on 30.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class FSParser {
    public static let tagsPattern = ###"""
        (?:\A|\s|[^\]]\()
        \#(
            [^
                \s          # no whitespace
                \#          # no hashes
                ,?!"`';:\.   # no punctuation
                \\          # no backslash
                (){}\[\]    # no bracket pairs
            ]+
        )
    """###

    /*
     ```
     Code
     ```

     Code
     */
    public static let codeQuoteBlockPattern = [
        "(?<=\\n|\\A)",
        "(^```[\\S\\ \\(\\)]*\\n([\\s\\S]*?)\\n```(?:\\n|\\Z))"
        ].joined(separator: "\n")

    public static let codeSpanPattern = [
            "(?<![\\\\`])   # Character before opening ` can't be a backslash or backtick",
            "(`+)           # $1 = Opening run of `",
            "(?!`)          # and no more backticks -- match the full run",
            "(.+?)          # $2 = The code block",
            "(?<!`)",
            "\\1",
            "(?!`)"
            ].joined(separator: "\n")

    public static let imageInlinePattern = [
        "(                     # wrap whole match in $1",
        "  !\\[",
        "      ([^\\[\\]]*?)           # alt text = $2",
        "  \\]",
        "  \\s?                # one optional whitespace character",
        "  \\(                 # literal paren",
        "      \\p{Z}*",
        "      (\(getNestedParensPattern()))    # href = $3",
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

    public static var nestedBracketsPattern = String()
    public static var nestedParensPattern = String()

    /// Reusable pattern to match balanced (parens). See Friedl's
    /// "Mastering Regular Expressions", 2nd Ed., pp. 328-331.
    public static func getNestedParensPattern() -> String {
        // in other words (this) and (this(also)) and (this(also(too)))
        // up to _nestDepth
        if nestedParensPattern.isEmpty {
            nestedParensPattern = repeatString([
                "(?>            # Atomic matching",
                "[^()\\s]+      # Anything other than parens or whitespace",
                "|",
                "\\("
                ].joined(separator: "\n"), 6) +
                repeatString(" \\))*", 6)
        }

        return nestedParensPattern
    }

    /// this is to emulate what's available in PHP
    public static func repeatString(_ text: String, _ count: Int) -> String {
        return Array(repeating: text, count: count).reduce("", +)
    }

    public static let imageInlineRegex = FSParserRegex(pattern: imageInlinePattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])

    public static let tagsInlineRegex = FSParserRegex(pattern: tagsPattern, options: [.allowCommentsAndWhitespace, .anchorsMatchLines])

    public static func getFencedCodeBlockRange(paragraphRange: NSRange, string: NSMutableAttributedString) -> NSRange? {
        guard UserDefaultsManagement.codeBlockHighlight else { return nil }

        let regex = try? NSRegularExpression(pattern: FSParser.codeQuoteBlockPattern, options: [
            NSRegularExpression.Options.allowCommentsAndWhitespace,
            NSRegularExpression.Options.anchorsMatchLines
            ])

        var foundRange: NSRange?
        regex?.enumerateMatches(
            in: string.string,
            options: NSRegularExpression.MatchingOptions(),
            range: NSRange(0..<string.length),
            using: { (result, _, stop) -> Void in
                guard let subResult = result else {
                    return
                }

                if subResult.range.intersection(paragraphRange) != nil {
                    if subResult.range.upperBound < string.length {
                        foundRange = NSRange(location: subResult.range.location, length: subResult.range.length)
                    } else {
                        foundRange = subResult.range
                    }

                    stop.pointee = true
                }
            }
        )

        return foundRange
    }

    public static func getSpanCodeBlockRange(content: NSMutableAttributedString, range: NSRange) -> NSRange? {
        var codeSpan: NSRange?
        let paragraphRange = content.mutableString.paragraphRange(for: range)
        let paragraph = content.attributedSubstring(from: paragraphRange).string

        if paragraph.contains("`") {
            FSParserRegex(pattern: codeSpanPattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators]).matches(content.string, range: paragraphRange) { (result) -> Void in
                if let spanRange = result?.range, spanRange.intersection(range) != nil {
                    codeSpan = spanRange
                }
            }
        }

        return codeSpan
    }
}

public struct FSParserRegex {
    public let regularExpression: NSRegularExpression!

    public init(pattern: String, options: NSRegularExpression.Options = NSRegularExpression.Options(rawValue: 0)) {
        var error: NSError?
        let regexp: NSRegularExpression?
        do {
            regexp = try NSRegularExpression(pattern: pattern,
                                         options: options)
        } catch let error1 as NSError {
            error = error1
            regexp = nil
        }

        // If re is nil, it means NSRegularExpression didn't like
        // the pattern we gave it.  All regex patterns used by Markdown
        // should be valid, so this probably means that a pattern
        // valid for .NET Regex is not valid for NSRegularExpression.
        if regexp == nil {
            if let error = error {
                print("Regular expression error: \(error.userInfo)")
            }
            assert(regexp != nil)
        }

        self.regularExpression = regexp
    }

    public func matches(_ input: String, range: NSRange, completion: @escaping (_ result: NSTextCheckingResult?) -> Void) {
        let sInput = input as NSString
        let options = NSRegularExpression.MatchingOptions(rawValue: 0)

        regularExpression.enumerateMatches(in: sInput as String, options: options, range: range, using: {(result, _, _) -> Void in
            completion(result)
        })
    }
}
