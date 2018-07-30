//
//  File.swift
//  FSNotes
//
//  Created by Christopher Reimann on 7/14/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import XCTest
@testable import FSNotesCore_macOS

class UserDataServiceTests: XCTestCase {

    var service: UserDataService!

    override func setUp() {
        super.setUp()
        service = UserDataService()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testSearchTrigger() {
        XCTAssertFalse(service.searchTrigger)

        service.searchTrigger = true
        XCTAssertTrue(service.searchTrigger)

        service.searchTrigger = false
        XCTAssertFalse(service.searchTrigger)
    }

    func testLastRenamed() {
        XCTAssert(service.lastRenamed == nil)

        service.lastRenamed = URL(string: "file:///tmp/foo")
        XCTAssertEqual(service.lastRenamed?.absoluteString, URL(string: "file:///tmp/foo")?.absoluteString)

        service.lastRenamed = nil
        XCTAssertNil(service.lastRenamed)
    }

    func testFsUpdatesDisabled() {
        XCTAssertFalse(service.fsUpdatesDisabled)

        service.fsUpdatesDisabled = true
        XCTAssertTrue(service.fsUpdatesDisabled)

        service.fsUpdatesDisabled = false
        XCTAssertFalse(service.fsUpdatesDisabled)
    }

    func testSkipListReload() {
        XCTAssertFalse(service.skipListReload)

        service.skipListReload = true
        XCTAssertTrue(service.skipListReload)

        service.skipListReload = false
        XCTAssertFalse(service.skipListReload)
    }
}
