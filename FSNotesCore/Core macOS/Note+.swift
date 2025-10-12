//
//  Note+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension Note {
    public func cache() {
        if cacheLock { return }

        let hash = content.string.fnv1a
        cacheLock = true

        if let copy = content.mutableCopy() as? NSMutableAttributedString {
            NotesTextProcessor.highlight(attributedString: copy)
            cacheCodeBlocks()

            if content.string.fnv1a == copy.string.fnv1a {
                content = copy
                cacheHash = hash
            }
        }

        cacheLock = false
    }
}
