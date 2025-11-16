//
//  NSAttributedStringKey+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/15/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public extension NSAttributedString.Key {
    static var fsAttachment: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.attachment")
    }

    static var attachmentUrl: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.image.url")
    }

    static var attachmentPath: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.image.path")
    }

    static var attachmentTitle: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.image.title")
    }

    static var todo: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.image.todo")
    }

    static var tag: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.attributed.tag")
    }

    static var yamlBlock: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.yaml")
    }
}
