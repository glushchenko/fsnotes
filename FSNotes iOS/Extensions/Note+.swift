//
//  Note+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/26/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension Note {
    public func write(with date: Date? = nil, from filesWrapper: FileWrapper? = nil, shouldOverwrite: Bool = false) {
        let wrapper = filesWrapper ?? getFileWrapper()
        let document = UINote(fileURL: url, textWrapper: wrapper)

        var attributes: [AnyHashable: Any]?
        if let creationDate = date {
            attributes = [FileAttributeKey.creationDate: creationDate]
        }

        do {
            try document.writeContents(wrapper, andAttributes: attributes, safelyTo: url, for: .forCreating)
        } catch {
            document.save(to: url, for: .forCreating, completionHandler: nil)
        }
    }
}
