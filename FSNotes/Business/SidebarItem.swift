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
        if let icon = type.icon {
            self.icon = getIcon(name: icon)
        }

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

        if let icon = self.type.icon {
            self.icon = getIcon(name: icon)
        }
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

        if let icon = type.icon {
            self.icon = getIcon(name: icon)
        }
    }

#if os(OSX)
    public func getIcon(name: String, white: Bool = false) -> NSImage? {
        let image = NSImage(named: name)
        image?.isTemplate = true

        if UserDefaults.standard.value(forKey: "AppleAccentColor") != nil {
            return image?.tint(color: NSColor.controlAccentColor)
        } else if white && !NSAppearance.current.isDark {
            return image?.tint(color: .white)
        } else {
            return image?.tint(color: NSColor(red: 0.08, green: 0.60, blue: 0.85, alpha: 1.00))
        }
    }
#else
    public func getIcon(name: String) -> UIImage? {
        guard let image = UIImage(named: name) else { return nil }

        return image.imageWithColor(color1: UIColor.mainTheme)
    }
#endif
}
