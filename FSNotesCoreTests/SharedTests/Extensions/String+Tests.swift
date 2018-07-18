//
//  String+.swift
//  FSNotes
//
//  Created by Christopher Reimann on 7/14/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import XCTest
#if os(OSX)
@testable import FSNotesCore_macOS
#elseif os(iOS)
@testable import FSNotesCore_iOS
#endif

class StringExtensionTests: XCTestCase {

    func testCondenseWhitespace() {
        XCTAssertEqual("  \nhello world\n\nwhat's up\n".condenseWhitespace(), "hello world what's up")
    }

    func testLocalizedStandardContains() {
        XCTAssertTrue(
            "hello world".localizedStandardContains("hello world".split(separator: " "))
        )
        XCTAssertTrue(
            "hello world".localizedStandardContains(["world"])
        )
        XCTAssertFalse(
            "hello world".localizedStandardContains("goodbye all".split(separator: " "))
        )
    }

    func testTrim() {
        XCTAssertEqual("  \n  \nhello world\n\n    ".trim(), "\n  \nhello world\n\n")
    }
}
