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
    static func getKey(fileExtension: String) -> [NSAttributedString.DocumentAttributeKey : Any] {
        var options: [NSAttributedString.DocumentAttributeKey : Any]
        
        if (fileExtension == "rtf") {
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
    
    static func getReadingOptionKey(fileExtension: String) -> [NSAttributedString.DocumentReadingOptionKey : Any] {
        if (fileExtension == "rtf") {
            return [
                .documentType : NSAttributedString.DocumentType.rtf
            ]
        }
    
        return [
            .documentType : NSAttributedString.DocumentType.plain,
            .characterEncoding : NSNumber(value: String.Encoding.utf8.rawValue)
        ]
    }
    
}
