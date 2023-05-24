//
//  EditorSelectionRect.swift
//  FSNotes iOS
//
//  Created by Александр on 11.02.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class EditorSelectionRect: UITextSelectionRect {
    private let original: UITextSelectionRect
    private var customRect: CGRect? = nil

    override var rect: CGRect {
        if let customRect = customRect {
            return customRect
        }

        return original.rect
    }

    override var writingDirection: NSWritingDirection {
        return original.writingDirection
    }

    override var containsStart: Bool {
        return original.containsStart
    }

    override var containsEnd: Bool {
        return original.containsEnd
    }

    override var isVertical: Bool {
        return original.isVertical
    }

    init(originalRect original: UITextSelectionRect, rect: CGRect) {
        self.original = original
        self.customRect = rect
    }
}
