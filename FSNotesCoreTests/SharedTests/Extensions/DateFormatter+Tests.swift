//
//  DateFormatter+Tests.swift
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

class DateFormatterExtensionTests: XCTestCase {
    let secondsFromGMT = NSLocale.autoupdatingCurrent.calendar.timeZone.secondsFromGMT()
    var formatter: DateFormatter!

    override func setUp() {
        formatter = DateFormatter()
    }

    func testFormatDateForDisplay() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let df = DateFormatter()
        df.locale = NSLocale.autoupdatingCurrent
        df.dateStyle = .short
        df.timeStyle = .none

        XCTAssertEqual(formatter.formatDateForDisplay(date), df.string(from: date))
    }

    func testFormatTimeForDisplay() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let df = DateFormatter()
        df.locale = NSLocale.autoupdatingCurrent
        df.dateStyle = .none
        df.timeStyle = .short

        XCTAssertEqual(formatter.formatTimeForDisplay(date), df.string(from: date))
    }

    func testformatForDuplicate() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let df = DateFormatter()
        df.locale = NSLocale.autoupdatingCurrent
        df.dateFormat = "yyyyMMddhhmmss"

        XCTAssertEqual(formatter.formatForDuplicate(date), df.string(from: date))

    }
}
