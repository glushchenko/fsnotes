//
//  SidebarItemType.swift
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

enum SidebarItemType: Int {
    case Label = 0x00
    case All = 0x01
    case Trash = 0x02    
    case Todo = 0x06
    case Inbox = 0x07
    case Tag = 0x08
    case Project = 0x09
    case Header = 0x10
    case Untagged = 0x11
    case ProjectEncryptedLocked = 12
    case ProjectEncryptedUnlocked = 13
    case Separator = 14

    public var icon: String? {
        switch self {
        case .Label: return nil
        case .All: return "sidebar_notes"
        case .Trash: return "sidebar_trash"
        case .Todo: return "sidebar_todo"
        case .Inbox: return "sidebar_inbox"
        case .Tag: return "sidebar_tag"
        case .Project: return "sidebar_project"
        case .Header: return "sidebar_icloud_drive"
        case .Untagged: return "sidebar_untagged"
        case .ProjectEncryptedLocked: return "sidebar_project_encrypted_locked"
        case .ProjectEncryptedUnlocked: return "sidebar_project_encrypted_unlocked"
        case .Separator: return nil
        }
    }
    
#if os(OSX)
    public func getIcon(white: Bool = false) -> NSImage? {
        guard let icon = icon else { return nil }

        let image = NSImage(named: icon)
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
    public func getIcon() -> UIImage? {
        guard let icon = icon, let image = UIImage(named: icon) else { return nil }

        return image.imageWithColor(color1: UIColor.mainTheme)
    }
#endif
}
