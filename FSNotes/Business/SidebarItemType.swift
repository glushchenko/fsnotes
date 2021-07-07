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
    case Archive = 0x05
    case Todo = 0x06
    case Inbox = 0x07
    case Tag = 0x08
    case Project = 0x09

    #if os(OSX)
    public func getIcon(white: Bool = false) -> NSImage? {
        let postfix = white ? "_white" : String()

        switch rawValue {
        case 0x01:
            return NSImage(named: "sidebar_notes" + postfix)
        case 0x02:
            return NSImage(named: "sidebar_trash" + postfix)
        case 0x05:
            return NSImage(named: "sidebar_archive" + postfix)
        case 0x06:
            return NSImage(named: "sidebar_todo" + postfix)
        case 0x07:
            return NSImage(named: "sidebar_inbox" + postfix)
        case 0x08:
            return NSImage(named: "sidebar_tag" + postfix)
        case 0x09:
            return NSImage(named: "sidebar_project" + postfix)
        default:
            return nil
        }
    }
    #endif
}
