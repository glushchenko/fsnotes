//
//  SingleTouchDownGestureRecognizer.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 8/30/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit.UIGestureRecognizerSubclass

class SingleTouchDownGestureRecognizer: UIGestureRecognizer {
    private var beginTimer: Timer?
    private var beginTime: Date?
    public var isLongPress: Bool = false
    public var touchCharIndex: Int?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if touches.count > 1 {
            self.state = .failed
        }

        if self.state == .possible {
            for touch in touches {
                guard let view = self.view as? EditTextView else { continue }

                let characterIndex = view.layoutManager.characterIndex(for: touch.location(in: view), in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
                self.touchCharIndex = characterIndex

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
                let maxX = Int(view.frame.width - 50)
                let minX = Int(50)

                let isImage = view.isImage(at: glyphIndex)
                let glyphRect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: view.textContainer)

                if isImage, glyphIndex < view.textStorage.length, glyphRect.contains(point) {
                    if Int(location.x) > minX && Int(location.x) < maxX {
                        view.lasTouchPoint = touch.location(in: view.superview)
                        self.state = .possible
                        return
                    } else {
                        self.state = .failed
                        return
                    }
                }

                if !isImage && glyphRect.contains(point) && view.isLink(at: characterIndex) {
                    self.state = .possible
                    return
                }
            }

            self.state = .failed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .possible {
            for touch in touches {
                guard let view = self.view as? EditTextView else { continue }

                let characterIndex = view.layoutManager.characterIndex(for: touch.location(in: view), in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
                self.touchCharIndex = characterIndex

                if view.isImage(at: characterIndex) {
                    self.state = .recognized
                    return
                }

                let point = touch.location(in: view)
                if view.isTodo(at: characterIndex) {
                    self.state = .recognized
                    return
                }

                let glyphRect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: characterIndex, length: 1), in: view.textContainer)
                if glyphRect.contains(point) && view.isLink(at: characterIndex) {
                    self.state = .recognized
                    return
                }
            }

            self.state = .failed
        }
    }
}
