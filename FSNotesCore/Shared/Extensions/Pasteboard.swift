//
//  NSPasteboard+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 25.09.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

#if os(macOS)
import Cocoa

extension NSPasteboard {
    public static var note: NSPasteboard.PasteboardType {
        .init("es.fsnot.pasteboard.note")
    }

    public static var project: NSPasteboard.PasteboardType {
        .init("es.fsnot.pasteboard.project")
    }

    public static var rtfd: NSPasteboard.PasteboardType {
        .init("es.fsnot.pasteboard.rtfd")
    }
}

#elseif os(iOS)
import UIKit

extension UIPasteboard {
    public static var attributed: String {
        "es.fsnot.pasteboard.attributed"
    }
}
#endif
