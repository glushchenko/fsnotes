//
//  Preferences.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/8/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public class UserDefaultsManagement {
    static var DefaultFont = "Source Code Pro"
    
    private struct Constants {
        static let FontNameKey = "font"
        static let TableOrientation = "isUseHorizontalMode"
        static let StoragePathKey = "storageUrl"
        static let StorageExtensionKey = "fileExtension"
    }
        
    static var fontName: String {
        get {
            if let returnFontName = UserDefaults.standard.object(forKey: Constants.FontNameKey) {
                return returnFontName as! String
            } else {
                return self.DefaultFont
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.FontNameKey)
        }
    }
    
    static var horizontalOrientation: Bool {
        get {
            if let returnMode = UserDefaults.standard.object(forKey: Constants.TableOrientation) {
                return returnMode as! Bool
            } else {
                return false
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.TableOrientation)
        }
    }
    
    static var storagePath: String {
        get {
            if let storagePath = UserDefaults.standard.object(forKey: Constants.StoragePathKey) {
                return storagePath as! String
            } else {
                return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.absoluteString
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.StoragePathKey)
        }
    }
    
    static var storageUrl: URL {
        get {
            return URL.init(fileURLWithPath: self.storagePath)
        }
    }
    
    static var storageExtension: String {
        get {
            if let storageExtension = UserDefaults.standard.object(forKey: Constants.StorageExtensionKey) {
                return storageExtension as! String
            } else {
                return "md"
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.StorageExtensionKey)
        }
    }
}
