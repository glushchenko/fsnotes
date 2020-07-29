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

    public var tag: Int {
        switch self {
        case .uuid: return 0x00
        case .autoRename: return 0x01        }
    }
}
