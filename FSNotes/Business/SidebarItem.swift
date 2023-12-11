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
    public var tag: FSTag?
    
    init(name: String, project: Project? = nil, type: SidebarItemType, icon: Image? = nil, tag: FSTag? = nil) {
        self.name = name
        self.project = project
        self.type = type
        self.icon = icon
        self.tag = tag

    #if os(iOS)
        self.icon = self.type.getIcon()

        guard let project = project, type == .Project else { return }

        if project.isEncrypted {
            if project.isLocked() {
                self.type = .ProjectEncryptedLocked
            } else {
                self.type = .ProjectEncryptedUnlocked
            }
        } else {
            self.type = .Project
        }

        self.icon = self.type.getIcon()
    #endif
    }

    public func getName() -> String {
        return name
    }
        
    public func isSelectable() -> Bool {
        if type == .Header && project == nil {
            return false
        }

        if type == .Separator {
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

    public func isSystem() -> Bool {
        let system: [SidebarItemType] = [.All, .Trash, .Todo]

        return system.contains(type)
    }

    public func load(type: SidebarItemType) {
        self.type = type
        self.icon = type.getIcon()
    }
}
