//
//  String+.swift
//  FSNotes
//
//  Created by Jeff Hanbury on 29/08/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension String {
    func condenseWhitespace() -> String {
        let components = self.components(separatedBy: NSCharacterSet.whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

    // Search the string for the existence of any of the terms in the provided array of terms.
    // Inspired by magic from https://stackoverflow.com/a/41902740/2778502
    func localizedStandardContains<S: StringProtocol>(_ terms: [S]) -> Bool {
        return terms.first(where: { localizedStandardContains($0) }) != nil
    }
    
    func trim() -> String {
        return self.trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
}
