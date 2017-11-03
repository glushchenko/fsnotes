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
    static func getDocumentAttributes(fileExtension: String) -> [String : Any] {
        var options: [String : Any]
        
        let font = NSFont(name: UserDefaultsManagement.fontName, size: CGFloat(UserDefaultsManagement.fontSize))
        
        if (fileExtension == "rtf") {
            options = [
                NSAttributedString.DocumentAttributeKey.documentType.rawValue : NSAttributedString.DocumentType.rtf,
                NSAttributedStringKey.font.rawValue: font!
            ]
        } else {
            options = [
                NSAttributedString.DocumentAttributeKey.documentType.rawValue : NSAttributedString.DocumentType.plain,
                NSAttributedStringKey.font.rawValue: font!,
                NSAttributedString.DocumentAttributeKey.characterEncoding.rawValue : NSNumber(value: String.Encoding.utf8.rawValue)
            ]
        }
        
        return options
    }
}
