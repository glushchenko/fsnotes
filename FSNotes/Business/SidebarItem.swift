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
    public var tag: Tag?
    
    init(name: String, project: Project? = nil, type: SidebarItemType, icon: Image? = nil, tag: Tag? = nil) {
        self.name = name
        self.project = project
        self.type = type
        self.icon = icon
        self.tag = tag
    }

    public func getName() -> String {
        if type == .Tag, let tag = tag {
            return tag.getFullName()
        }

        return name
    }
        
    public func isSelectable() -> Bool {
        let tagsLabel = NSLocalizedString("Tags", comment: "Sidebar label")
        
        if type == .Label && ["# \(tagsLabel)"].contains(name) {
            return false
        }
        
        return true
    }
    
    public func isTrash() -> Bool {
        return (type == .Trash)
    }
    
    public func isGroupItem() -> Bool {
        let notesLabel = NSLocalizedString("Notes", comment: "Sidebar label")
        let trashLabel = NSLocalizedString("Trash", comment: "Sidebar label")
        if project == nil && [notesLabel, trashLabel].contains(name) {
            return true
        }
        
        return false
    }
}
