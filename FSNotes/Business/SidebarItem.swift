//
//  SidebarItem.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

#if os(OSX)
    import Cocoa
#else
    import UIKit
#endif

class SidebarItem {
    var name: String
    var project: Project?
    var type: SidebarItemType
    public var icon: Image?
    
    init(name: String, project: Project? = nil, type: SidebarItemType, icon: Image? = nil) {
        self.name = name
        self.project = project
        self.type = type
        self.icon = icon
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
