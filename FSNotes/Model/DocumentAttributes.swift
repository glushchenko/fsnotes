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
                NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType,
                NSFontAttributeName: font!
            ]
        } else {
            options = [
                NSDocumentTypeDocumentAttribute : NSPlainTextDocumentType,
                NSFontAttributeName: font!
            ]
        }
        
        return options
    }
}
