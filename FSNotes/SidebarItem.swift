//
//  SidebarItem.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class SidebarItem {
    var name: String
    var project: Project?
    var type: SidebarItemType
    
    init(name: String, project: Project? = nil, type: SidebarItemType) {
        self.name = name
        self.project = project
        self.type = type
    }
}
