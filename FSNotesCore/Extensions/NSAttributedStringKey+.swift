//
//  NSAttributedStringKey+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/15/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public extension NSAttributedString.Key {
    static var attachmentSave: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.attachment.save")
    }

    static var attachmentUrl: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.attachment.url")
    }

    static var attachmentPath: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.attachment.path")
    }

    static var attachmentTitle: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.attachment.title")
    }

    static var todo: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.todo")
    }

    static var tag: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.tag")
    }

    static var yamlBlock: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.yaml")
    }

    static var highlight: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "es.fsnot.highlight")
    }
}
