//
//  NSPasteboard+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 25.09.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

extension NSPasteboard {
    public static var noteType: PasteboardType {
        return NSPasteboard.PasteboardType("es.fsnot.pasteboard.note")
    }
}
