//
//  SettingsFilesNaming.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 19.06.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

enum SettingsFilesNaming: Int {
    case uuid
    case autoRename
    case untitledNote
    case date
    case altDate
    case autoRenameNew

    public var tag: Int {
        switch self {
        case .uuid: return 0x00
        case .autoRename: return 0x01
        case .untitledNote: return 0x02
        case .date: return 0x03
        case .altDate: return 0x04
        case .autoRenameNew: return 0x05
        }
    }

    public func getName() -> String {
        switch self {
        case .uuid, .autoRename, .autoRenameNew:
            return UUID().uuidString
        case .untitledNote:
            return "Untitled Note"
        case .date:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMddHHmmss"
            return formatter.string(from: Date())
        case .altDate:
            let dateFromatter = DateFormatter()
            dateFromatter.amSymbol = "AM"
            dateFromatter.pmSymbol = "PM"

            dateFromatter.dateFormat = "yyyy-MM-dd hh.mm.ss a"
            let date = dateFromatter.string(from: Date())
            return date
        }
    }
}
