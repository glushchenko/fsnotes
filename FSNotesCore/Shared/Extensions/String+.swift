//
//  String+.swift
//  FSNotes
//
//  Created by Jeff Hanbury on 29/08/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public extension String {
    func condenseWhitespace() -> String {
        let components = self.components(separatedBy: NSCharacterSet.whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

    // Search the string for the existence of any of the terms in the provided array of terms.
    // Inspired by magic from https://stackoverflow.com/a/41902740/2778502
    func localizedStandardContains<S: StringProtocol>(_ terms: [S]) -> Bool {
        return terms.first(where: { self.localizedStandardContains($0) }) != nil
    }

    func trim() -> String {
        return self.trimmingCharacters(in: NSCharacterSet.whitespaces)
    }

    func getPrefixMatchSequentially(char: String) -> String? {
        var result = String()

        for current in self {
            if current.description == char {
                result += char
                continue
            }
            break
        }

        if result.count > 0 {
            return result
        }

        return nil
    }

    func localizedCaseInsensitiveContainsTerms(_ terms: [Substring]) -> Bool {
        // Use magic from https://stackoverflow.com/a/41902740/2778502
        return terms.first(where: { !self.localizedLowercase.contains($0) }) == nil
    }

    func removeLastNewLine() -> String {
        if self.last == "\n" {
            return String(self.dropLast())
        }

        return self
    }

    var isValidUUID: Bool {
        return UUID(uuidString: self) != nil
    }

    func escapePlus() -> String {
        return self.replacingOccurrences(of: "+", with: "%20")
    }

    subscript(_ ind: Int) -> String {
        let idx1 = utf16.index(startIndex, offsetBy: ind)
        let idx2 = utf16.index(idx1, offsetBy: 1)
        return String(self[idx1..<idx2])
    }

    subscript (rind: Range<Int>) -> String {
        let start = utf16.index(startIndex, offsetBy: rind.lowerBound)
        let end = utf16.index(startIndex, offsetBy: rind.upperBound)
        return String(self[start..<end])
    }

    subscript (rind: CountableClosedRange<Int>) -> String {
        let startIndex = utf16.index(self.startIndex, offsetBy: rind.lowerBound)
        let endIndex = utf16.index(startIndex, offsetBy: rind.upperBound - rind.lowerBound)
        return String(self[startIndex...endIndex])
    }

    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: [.dotMatchesLineSeparators]) else { return [] }

        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
}

extension StringProtocol where Index == String.Index {
    public func nsRange(from range: Range<Index>) -> NSRange {
        return NSRange(range, in: self)
    }
}
