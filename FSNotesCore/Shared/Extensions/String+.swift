//
//  String+.swift
//  FSNotes
//
//  Created by Jeff Hanbury on 29/08/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import CommonCrypto

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

public extension String {
    #if os(OSX)
    typealias Font = NSFont
    #else
    typealias Font = UIFont
    #endif

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

    func isValidEmail() -> Bool {
        let pattern = "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            return regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count)) != nil
        }

        return false
    }

    var isValidUUID: Bool {
        return UUID(uuidString: self) != nil
    }

    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    var isWhitespace: Bool {
        guard !isEmpty else { return true }

        let whitespaceChars = NSCharacterSet.whitespacesAndNewlines

        return self.unicodeScalars
            .filter { (unicodeScalar: UnicodeScalar) -> Bool in !whitespaceChars.contains(unicodeScalar) }
            .count == 0
    }

    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }

    var isContainsLetters: Bool {
        let letters = CharacterSet.letters
        return self.rangeOfCharacter(from: letters) != nil
    }

    var withoutSpecialCharacters: String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: " ")
                .condenseWhitespace()
    }

    func escapePlus() -> String {
        return self.replacingOccurrences(of: "+", with: "%20")
    }

    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: [.dotMatchesLineSeparators]) else { return [] }

        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: NSRange(0..<nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }

    func trunc(length: Int) -> String {
        let result = self
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "")

        return (result.count > length) ? String(result.prefix(length)) : result
    }

    func startsWith(string: String) -> Bool {
        guard let range = range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return false
        }
        return range.lowerBound == startIndex
    }

    func widthOfString(usingFont font: Font, tabs: [NSTextTab]? = nil) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        if let tabs = tabs {
            paragraph.tabStops = tabs
        }

        let fontAttributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.paragraphStyle: paragraph
        ]

        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }

    func getSpacePrefix() -> String {
        var prefix = String()
        for char in unicodeScalars {
            if char == "\t" || char == " " {
                prefix += String(char)
            } else {
                break
            }
        }
        return prefix
    }

    func substring(with nsRange: NSRange) -> Substring? {
        guard let range = Range(nsRange, in: self) else { return nil }
        return self[range]
    }

    func replaced(from: String, to: String, by new: String) -> String {
        guard let from = range(of: from)?.lowerBound, let to = range(of: to)?.upperBound else { return self }

        let range = from..<to
        return replacingCharacters(in: range, with: new)
    }

    static func random(length: Int = 20) -> String {
         let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
         var randomString: String = ""

         for _ in 0..<length {
             let randomValue = arc4random_uniform(UInt32(base.count))
             randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
         }
         return randomString
     }

    // Join multibyte chars 1081 774 (и  ̆) to 1081 (й), important for proper length (git integration fn: git_tree_entry_bypath)
    func recode4byteString() -> String {
        if let decodedString = self.applyingTransform(.stripCombiningMarks, reverse: true) {
            return decodedString
        }

        return self
    }

    func isHexColor() -> Bool {
        return self.count == 6 && self.allSatisfy({ $0.isHexDigit })
    }

    func swiftRange(from nsRange: NSRange) -> Range<String.Index>? {
        guard let start = index(at: nsRange.location),
              let end = index(at: nsRange.location + nsRange.length) else {
            return nil
        }
        return start..<end
    }

    private func index(at location: Int) -> String.Index? {
        return self.index(startIndex, offsetBy: location, limitedBy: endIndex)
    }
}

extension StringProtocol where Index == String.Index {
    public func nsRange(from range: Range<Index>) -> NSRange {
        return NSRange(range, in: self)
    }
}

public extension String {
  subscript(value: Int) -> Character {
    self[index(at: value)]
  }
}

public extension String {
  subscript(value: NSRange) -> Substring {
    self[value.lowerBound..<value.upperBound]
  }
}

public extension String {
  subscript(value: CountableClosedRange<Int>) -> Substring {
    self[index(at: value.lowerBound)...index(at: value.upperBound)]
  }

  subscript(value: CountableRange<Int>) -> Substring {
    self[index(at: value.lowerBound)..<index(at: value.upperBound)]
  }

  subscript(value: PartialRangeUpTo<Int>) -> Substring {
    self[..<index(at: value.upperBound)]
  }

  subscript(value: PartialRangeThrough<Int>) -> Substring {
    self[...index(at: value.upperBound)]
  }

  subscript(value: PartialRangeFrom<Int>) -> Substring {
    self[index(at: value.lowerBound)...]
  }
}

private extension String {
  func index(at offset: Int) -> String.Index {
    index(startIndex, offsetBy: offset)
  }
}
