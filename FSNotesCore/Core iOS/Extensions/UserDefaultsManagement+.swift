//
//  UserDefaultsManagement+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/26/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import NightNight

extension UserDefaultsManagement {
    private struct Constants {
        static let codeTheme = "codeTheme"
        static let StorageExtensionKey = "fileExtension"
    }

    static var storageExtension: String {
        get {
            let defaults = UserDefaults.init(suiteName: "group.fsnotes-manager")

            if let storageExtension = UserDefaults.standard.object(forKey: Constants.StorageExtensionKey) as? String {

                // Resave settings in global namespace
                UserDefaultsManagement.storageExtension = storageExtension
                UserDefaults.standard.removeObject(forKey: Constants.StorageExtensionKey)
            }

            if let ext = defaults?.object(forKey: Constants.StorageExtensionKey) as? String {
                return ext
            }

            return "md"
        }
        set {
            UserDefaults.init(suiteName: "group.fsnotes-manager")?.set(newValue, forKey: Constants.StorageExtensionKey)
        }
    }

    static var codeTheme: String {
        get {
            if let theme = UserDefaults.standard.object(forKey: Constants.codeTheme) as? String {
                return theme
            }

            if NightNight.theme == .night {
                return "monokai-sublime"
            }

            return "atom-one-light"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.codeTheme)
        }
    }
}
