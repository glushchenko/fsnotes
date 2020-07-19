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

    static func withExt(rawValue: String) -> NoteType {
        switch rawValue {
            case "markdown", "md", "mkd", "txt": return NoteType.Markdown
            case "rtf": return NoteType.RichText
            default: return NoteType.Markdown
        }
    }
    
    static func withTag(rawValue: Int) -> NoteType {
        switch rawValue {
        case 1: return .Markdown
        case 2: return .RichText
        default: return .Markdown
        }
    }
    
    static func withUTI(rawValue: String) -> NoteType {
        switch rawValue {
        case "net.daringfireball.markdown": return .Markdown
        case "public.rtf": return .RichText
        default: return .Markdown
        }
    }
        
    public var tag: Int {
        get {
            switch self {
            case .Markdown: return 1
            case .RichText: return 2
            }
        }
    }
    
    public var uti: String {
        get {
            switch self {
            case .Markdown: return "net.daringfireball.markdown"
            case .RichText: return "public.rtf"
            }
        }
    }
    
    public func getExtension(for container: NoteContainer) -> String {
        if self == .RichText {
            return "rtf"
        }

        return UserDefaultsManagement.noteExtension
    }
}
