//
//  SingleTouchDownGestureRecognizer.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 8/30/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit.UIGestureRecognizerSubclass

class SingleTouchDownGestureRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .possible {
            for touch in touches {
                guard let view = self.view as? EditTextView else { continue }

                if UIMenuController.shared.isMenuVisible {
                    UIMenuController.shared.setMenuVisible(false, animated: false)
                }

                let point = touch.location(in: view)
                let glyphIndex = view.layoutManager.glyphIndex(for: point, in: view.textContainer)

                if view.isTodo(at: glyphIndex) {
                    self.state = .possible
                    return
                }

                let location = touch.location(in: view)
                let maxX = Int(view.frame.width - 13)
                let minX = Int(13)

                let isImage = view.isImage(at: glyphIndex)
                let glyphRect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: view.textContainer)

                if Int(location.x) > minX && Int(location.x) < maxX, isImage, glyphIndex < view.textStorage.length, glyphRect.contains(point) {
                    view.lasTouchPoint = touch.location(in: view.superview)
                    self.state = .possible
                    return
                }

                if !isImage && glyphRect.contains(point) && view.isLink(at: glyphIndex) && !view.isFirstResponder {
                    self.state = .possible
                    return
                }
            }

            self.state = .failed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        self.state = .possible
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .possible {
            for touch in touches {
                guard let view = self.view as? EditTextView else { continue }

                let characterIndex = view.layoutManager.characterIndex(for: touch.location(in: view), in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

                if view.isImage(at: characterIndex) {
                    self.state = .recognized
                    return
                }

                let point = touch.location(in: view)
                let glyphIndex = view.layoutManager.glyphIndex(for: point, in: view.textContainer)
                if view.isTodo(at: glyphIndex) {
                    self.state = .recognized
                    return
                }

                let glyphRect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: view.textContainer)
                if glyphRect.contains(point) && view.isLink(at: glyphIndex) && !view.isFirstResponder {
                    self.state = .recognized
                    return
                }
            }

            self.state = .failed
        }
    }
}
