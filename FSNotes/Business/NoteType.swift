//
//  NoteFileType.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/6/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

enum NoteType: String {
    case Markdown = "md"
    case RichText = "rtf"
    case PlainText = "txt"
    case TextBundle = "textbundle"
    
    static func withExt(rawValue: String) -> NoteType {
        switch rawValue {
            case "markdown", "md", "mkd": return NoteType.Markdown
            case "rtf": return NoteType.RichText
            case "textbundle": return NoteType.TextBundle
            default: return NoteType.PlainText
        }
    }
}
