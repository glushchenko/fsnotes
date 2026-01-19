//
//  HtmlExtractor.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 24.08.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

public  func extractTitle(from htmlString: String) -> String? {
    let lowercasedHTML = htmlString.lowercased()

    guard let titleStartRange = lowercasedHTML.range(of: "<title") else {
        return nil
    }

    let afterTitleTag = htmlString[titleStartRange.upperBound...]
    guard let closingBracketRange = afterTitleTag.range(of: ">") else {
        return nil
    }

    let titleContentStart = closingBracketRange.upperBound
    let remainingHTML = htmlString[titleContentStart...]

    guard let endTitleRange = remainingHTML.range(of: "</title>", options: .caseInsensitive) else {
        return nil
    }

    let titleContent = String(remainingHTML[..<endTitleRange.lowerBound])

    return cleanHTMLString(titleContent)
}

public func cleanHTMLString(_ string: String) -> String {
    var cleaned = string

    let htmlEntities: [String: String] = [
        "&amp;": "&",
        "&lt;": "<",
        "&gt;": ">",
        "&quot;": "\"",
        "&apos;": "'",
        "&nbsp;": " "
    ]

    for (entity, replacement) in htmlEntities {
        cleaned = cleaned.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
    }

    let numericEntityPattern = "&#x?([0-9a-fA-F]+);"
    if let regex = try? NSRegularExpression(pattern: numericEntityPattern) {
        let range = NSRange(location: 0, length: cleaned.count)
        let matches = regex.matches(in: cleaned, range: range)

        for match in matches.reversed() {
            if let numberRange = Range(match.range(at: 1), in: cleaned) {
                let numberString = String(cleaned[numberRange])
                let isHex = cleaned[match.range].contains("&#x")

                var characterCode: Int?
                if isHex {
                    characterCode = Int(numberString, radix: 16)
                } else {
                    characterCode = Int(numberString)
                }

                if let code = characterCode, let unicodeScalar = UnicodeScalar(code) {
                    let character = String(Character(unicodeScalar))
                    if let fullRange = Range(match.range, in: cleaned) {
                        cleaned = cleaned.replacingCharacters(in: fullRange, with: character)
                    }
                }
            }
        }
    }

    return cleaned
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
}
