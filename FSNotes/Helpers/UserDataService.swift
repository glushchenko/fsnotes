//
//  UserDataService.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/30/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class UserDataService {
    static let instance = UserDataService()

    fileprivate var _isShortcutCall = false
    fileprivate var _searchTrigger = false
    fileprivate var _lastRenamed: URL? = nil
    fileprivate var _fsUpdates = false

    var isShortcutCall: Bool {
        get {
            return _isShortcutCall
        }
        set {
            _isShortcutCall = newValue
        }
    }

    var searchTrigger: Bool {
        get {
            return _searchTrigger
        }
        set {
            _searchTrigger = newValue
        }
    }

    var lastRenamed: URL? {
        get {
            return _lastRenamed
        }
        set {
            _lastRenamed = newValue
        }
    }

    var fsUpdatesDisabled: Bool {
        get {
            return _fsUpdates
        }
        set {
            _fsUpdates = newValue
        }
    }
}
