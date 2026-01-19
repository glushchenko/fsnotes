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

    static func withExt(rawValue: String) -> NoteType {
        switch rawValue {
            case "markdown", "md", "mkd", "txt": return NoteType.Markdown
            default: return NoteType.Markdown
        }
    }
    
    static func withTag(rawValue: Int) -> NoteType {
        switch rawValue {
        case 1: return .Markdown
        default: return .Markdown
        }
    }
    
    static func withUTI(rawValue: String) -> NoteType {
        switch rawValue {
        case "net.daringfireball.markdown": return .Markdown
        default: return .Markdown
        }
    }
        
    public var tag: Int {
        get {
            switch self {
            case .Markdown: return 1
            }
        }
    }
    
    public var uti: String {
        get {
            switch self {
            case .Markdown: return "net.daringfireball.markdown"
            }
        }
    }
    
    public func getExtension(for container: NoteContainer) -> String {
        return UserDefaultsManagement.noteExtension
    }
}
