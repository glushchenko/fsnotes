//
//  SettingsFilesNaming.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 19.06.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

enum SettingsFilesNaming: Int {
    case uuid
    case autoRename
    case untitledNote
    case dateTime

    public var tag: Int {
        switch self {
        case .uuid: return 0x00
        case .autoRename: return 0x01
        case .untitledNote: return 0x02
        case .dateTime: return 0x03
        }
    }
}
