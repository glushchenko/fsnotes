//
//  LanguageType.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

//
//  NoteFileType.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/6/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

enum LanguageType: Int {
    case English = 0x00
    case Russian = 0x01
    case Ukrainian = 0x02
    
    var description: String {
        get {
            switch(self.rawValue) {
            case 0x00: return "English"
            case 0x01: return "Русский"
            case 0x02: return "Українська"
            default: return ""
            }
        }
    }
    
    var code: String {
        get {
            switch(self.rawValue) {
            case 0x00: return "en"
            case 0x01: return "ru"
            case 0x02: return "uk"
            default: return "en"
            }
        }
    }
    
    static func withName(rawValue: String) -> LanguageType {
        switch rawValue {
        case "English": return LanguageType.English
        case "Русский": return LanguageType.Russian
        case "Українська": return LanguageType.Ukrainian
        default: return LanguageType.English
        }
    }
    
}
