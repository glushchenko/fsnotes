//
//  NoteFileType.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/6/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public enum NoteType: String {
    case Markdown = "md"
    case RichText = "rtf"
    case PlainText = "txt"
    case TextBundle = "textbundle"
    
    static func withExt(rawValue: String) -> NoteType {
        switch rawValue {
            case "rtf": return NoteType.RichText
            case "textbundle": return NoteType.TextBundle
            case "txt": return NoteType.PlainText
            default: return NoteType.Markdown
        }
    }
}
