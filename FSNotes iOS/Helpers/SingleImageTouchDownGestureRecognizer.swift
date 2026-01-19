//
//  SingleImageTouchDownGestureRecognizer.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 8/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit.UIGestureRecognizerSubclass

class SingleImageTouchDownGestureRecognizer: UIGestureRecognizer {
    public var isRightBorderTap = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if touches.count > 1 {
            self.state = .failed
        }

        if self.state == .possible {
            for touch in touches {
                guard let view = self.view as? EditTextView else { continue }

                let point = touch.location(in: view)
                let glyphIndex = view.layoutManager.glyphIndex(for: point, in: view.textContainer)

                let location = touch.location(in: view)
                let maxX = Int(view.frame.width - 50)
                let minX = Int(50)

                let isImage = view.isImage(at: glyphIndex)
                let glyphRect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: view.textContainer)

                if Int(location.x) < minX || Int(location.x) > maxX, isImage, glyphIndex < view.textStorage.length, glyphRect.contains(point) {
                    self.state = .possible

                    isRightBorderTap = Int(location.x) > maxX
                } else {
                    self.state = .failed
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .possible {
            for touch in touches {
                guard let view = self.view as? EditTextView else { continue }

                let point = touch.location(in: view)
                let glyphIndex = view.layoutManager.glyphIndex(for: point, in: view.textContainer)

                let location = touch.location(in: view)
                let maxX = Int(view.frame.width - 25)
                let minX = Int(25)

                let isImage = view.isImage(at: glyphIndex)
                let glyphRect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: view.textContainer)

                if Int(location.x) < minX || Int(location.x) > maxX, isImage, glyphIndex < view.textStorage.length, glyphRect.contains(point) {
                    self.state = .recognized
                } else {
                    self.state = .failed
                }
            }
        }
    }
}
