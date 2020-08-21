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
    case Deutsch = 0x03
    case Spanish = 0x04
    case Arabic = 0x05
    case Chinese = 0x06
    case Korean = 0x07
    case French = 0x08
    case Dutch = 0x09
    case Portuguese = 10
    case Italian = 11

    var description: String {
        get {
            switch(self.rawValue) {
            case 0x00: return "English"
            case 0x01: return "Русский"
            case 0x02: return "Українська"
            case 0x03: return "Deutsch"
            case 0x04: return "Spanish"
            case 0x05: return "Arabic"
            case 0x06: return "Chinese (Simplified)"
            case 0x07: return "Korean"
            case 0x08: return "French"
            case 0x09: return "Dutch"
            case 10: return "Portuguese"
            case 11: return "Italian"
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
            case 0x03: return "de"
            case 0x04: return "es"
            case 0x05: return "ar"
            case 0x06: return "zh-Hans"
            case 0x07: return "ko"
            case 0x08: return "fr"
            case 0x09: return "nl-NL"
            case 10: return "pt-PT"
            case 11: return "it"
            default: return "en"
            }
        }
    }
    
    static func withName(rawValue: String) -> LanguageType {
        switch rawValue {
        case "English": return LanguageType.English
        case "Русский": return LanguageType.Russian
        case "Українська": return LanguageType.Ukrainian
        case "Deutsch": return LanguageType.Deutsch
        case "Spanish": return LanguageType.Spanish
        case "Arabic": return LanguageType.Arabic
        case "Chinese (Simplified)": return LanguageType.Chinese
        case "Korean": return LanguageType.Korean
        case "French": return LanguageType.French
        case "Dutch": return LanguageType.Dutch
        case "Portuguese": return LanguageType.Portuguese
        case "Italian": return LanguageType.Italian
        default: return LanguageType.English
        }
    }

    static func withCode(rawValue: String) -> Int {
        switch(rawValue) {
            case "en": return 0x00
            case "ru": return 0x01
            case "uk": return 0x02
            case "de": return 0x03
            case "es": return 0x04
            case "ar": return 0x05
            case "zh-Hans": return 0x06
            case "ko": return 0x07
            case "fr": return 0x08
            case "nl-NL": return 0x09
            case "pt-PT": return 10
            case "it": return 11
            default: return 0x00
        }
    }
    
}
