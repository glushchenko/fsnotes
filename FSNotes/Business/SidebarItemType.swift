//
//  SidebarItemType.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

#if os(OSX)
import Cocoa
#endif

enum SidebarItemType: Int {
    case Label = 0x00
    case All = 0x01
    case Trash = 0x02

    #if os(iOS)
    case Category = 0x03
    #endif
    
    case Archive = 0x05
    case Todo = 0x06
    case Inbox = 0x07
    case Tag = 0x08
    case Project = 0x09
    case Header = 0x10
    case Untagged = 0x11

    #if os(OSX)
    public func getIcon(white: Bool = false) -> NSImage? {
        var image: NSImage? = nil
        
        switch rawValue {
        case 0x01:
            image = NSImage(named: "sidebar_notes")
        case 0x02:
            image = NSImage(named: "sidebar_trash")
        case 0x05:
            image = NSImage(named: "sidebar_archive")
        case 0x06:
            image = NSImage(named: "sidebar_todo")
        case 0x07:
            image = NSImage(named: "sidebar_inbox")
        case 0x08:
            image = NSImage(named: "sidebar_tag")
        case 0x09:
            image = NSImage(named: "sidebar_project")
        case 0x10:
            image = NSImage(named: "sidebar_icloud_drive")
        case 0x11:
            image = NSImage(named: "sidebar_untagged");
        default:
            return nil
        }
        
        if #available(macOS 10.14, *), UserDefaults.standard.value(forKey: "AppleAccentColor") != nil {
            return image?.tint(color: NSColor.controlAccentColor)
        } else if white {
            return image?.tint(color: .white)
        } else {
            return image
        }
    }
    #endif
}
