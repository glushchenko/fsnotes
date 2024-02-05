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
}
