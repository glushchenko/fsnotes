//
//  Note+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension Note {
    public func cache(backgroundThread: Bool = false) {
        if cachingInProgress {
            return
        }

        let hash = content.string.md5
        cachingInProgress = true

        if let copy = content.mutableCopy() as? NSMutableAttributedString {
            copy.removeAttribute(.backgroundColor, range: NSRange(0..<copy.length))

            NotesTextProcessor.highlightMarkdown(attributedString: copy, paragraphRange: NSRange(location: 0, length: copy.length), note: self)
            NotesTextProcessor.highlightFencedAndIndentCodeBlocks(attributedString: copy, backgroundThread: backgroundThread)

            if content.string.md5 == copy.string.md5 {
                content = copy
                cacheHash = hash
            }
        }

        cachingInProgress = false
    }
}
