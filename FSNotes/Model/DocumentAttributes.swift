//
//  DocumentAttributes.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/11/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Cocoa

class DocumentAttributes {
    static func getKey(type: NoteType) -> [NSAttributedString.DocumentAttributeKey : Any] {
        var options: [NSAttributedString.DocumentAttributeKey : Any]
        
        if (type == .RichText) {
            options = [
                .documentType : NSAttributedString.DocumentType.rtf
            ]
        } else {
            options = [
                .documentType : NSAttributedString.DocumentType.plain,
                .characterEncoding : NSNumber(value: String.Encoding.utf8.rawValue)
            ]
        }
        
        return options
    }
    
    static func getReadingOptionKey(type: NoteType) -> [NSAttributedString.DocumentReadingOptionKey : Any] {
        if (type == .RichText) {
            return [.documentType : NSAttributedString.DocumentType.rtf]
        }
    
        return [
            .documentType : NSAttributedString.DocumentType.plain,
            .characterEncoding : NSNumber(value: String.Encoding.utf8.rawValue)
        ]
    }
    
}
