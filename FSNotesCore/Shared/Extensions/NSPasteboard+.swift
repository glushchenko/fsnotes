//
//  NSPasteboard+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 25.09.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

extension NSPasteboard {
    public static var note: PasteboardType {
        return NSPasteboard.PasteboardType("es.fsnot.pasteboard.note")
    }

    public static var project: PasteboardType {
        return NSPasteboard.PasteboardType("es.fsnot.pasteboard.project")
    }

    public static var rtfd: PasteboardType {
        return NSPasteboard.PasteboardType("es.fsnot.pasteboard.rtfd")
    }

//    public static var attributed: PasteboardType {
//        return NSPasteboard.PasteboardType("es.fsnot.pasteboard.attributedText")
//    }
}
