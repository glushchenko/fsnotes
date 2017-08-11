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
    static func getDocumentAttributes(fileExtension: String) -> [String : AnyObject] {
        var options: [String : AnyObject]
        
        if (fileExtension == "rtf") {
            options = [
                NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType
                ] as [String : AnyObject]
        } else {
            options = [
                NSDocumentTypeDocumentAttribute : NSPlainTextDocumentType
                ] as [String : AnyObject]
        }
        
        return options
    }
}
