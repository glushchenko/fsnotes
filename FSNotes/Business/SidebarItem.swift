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
    
    public func hasPlusOnHover() -> Bool {
        if type == .Label && name != "# Tags" {
            return true
        }
        
        return false
    }
    
    public func isSelectable() -> Bool {        
        if type == .Label && ["# Tags"].contains(name) {
            return false
        }
        
        return true
    }
    
    public func isTrash() -> Bool {
        return (type == .Trash)
    }
    
    public func isGroupItem() -> Bool {
        if project == nil && ["Notes", "Trash"].contains(name) {
            return true
        }
        
        return false
    }
}
