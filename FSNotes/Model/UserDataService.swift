//
//  UserDataService.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/30/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

class UserDataService {
    static let instance = UserDataService()
    
    fileprivate var _isShortcutCall = false
    
    var isShortcutCall: Bool {
        get {
            return _isShortcutCall
        }
        set {
            _isShortcutCall = newValue
        }
    }
}
