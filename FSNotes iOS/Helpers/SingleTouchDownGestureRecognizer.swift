//
//  SingleTouchDownGestureRecognizer.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 8/30/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit.UIGestureRecognizerSubclass

class SingleTouchDownGestureRecognizer: UIGestureRecognizer {
    private let allowableTodoMovement: CGFloat = 10
    private var beginTimer: Timer?
    private var beginTime: Date?
    private var initialTouchPoint: CGPoint?
    private var isTodoTouch = false
    public var isLongPress: Bool = false
    public var touchCharIndex: Int?
    public var selectedRange: UITextRange?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let view = self.view as? EditTextView else { return }
        self.selectedRange = view.selectedTextRange
        view.isAllowedScrollRect = false

        if touches.count > 1 {
            self.state = .failed
            view.isAllowedScrollRect = true
            return
        }

        if self.state == .possible {
            for touch in touches {
                let point = touch.location(in: view)
                self.initialTouchPoint = point
                let characterIndex = view.layoutManager.characterIndex(for: point, in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
                self.touchCharIndex = characterIndex

                if UIMenuController.shared.isMenuVisible {
                    UIMenuController.shared.hideMenu(from: view)
                }

                let glyphIndex = view.layoutManager.glyphIndex(for: point, in: view.textContainer)

                if isTodoInTouchArea(point: point, characterIndex: characterIndex, view: view) && (self.selectedRange?.isEmpty == true || !view.isFirstResponder) {
                    // Wait for touchesEnded before recognizing the tap. Recognizing
                    // here toggles the checkbox before a scroll gesture can win.
                    self.isTodoTouch = true
                    return
                }
                
                let maxX = Int(view.frame.width - 50)
                let minX = Int(50)

                let isImage = view.isImage(at: characterIndex)
                let glyphRect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: view.textContainer)

                if isImage, characterIndex < view.textStorage.length, glyphRect.contains(point) {
                    if Int(point.x) > minX && Int(point.x) < maxX {
                        view.lasTouchPoint = touch.location(in: view.superview)
                        self.state = .possible
                        view.isAllowedScrollRect = true
                        return
                    } else {
                        self.state = .failed
                        view.isAllowedScrollRect = true
                        return
                    }
                }

                if !isImage && glyphRect.contains(point) && view.isLink(at: characterIndex) {
                    self.state = .possible
                    view.isAllowedScrollRect = true
                    return
                }
            }

            self.state = .failed
            view.isAllowedScrollRect = true
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard isTodoTouch,
              let view = self.view as? EditTextView,
              let initialTouchPoint,
              let touch = touches.first else { return }

        let point = touch.location(in: view)
        if hypot(point.x - initialTouchPoint.x, point.y - initialTouchPoint.y) > allowableTodoMovement {
            self.state = .failed
            view.isAllowedScrollRect = true
        }
    }

    private func isTodoInTouchArea(point: CGPoint, characterIndex: Int, view: EditTextView) -> Bool {
        func checkTodoInLine(lineRange: NSRange) -> Bool {
            let storage = view.textStorage
            let safeRange = NSIntersectionRange(
                lineRange,
                NSRange(location: 0, length: storage.length)
            )
            guard safeRange.length > 0 else { return false }

            var todoLocation: Int? = storage.attribute(
                .todo,
                at: safeRange.location,
                effectiveRange: nil
            ) == nil ? nil : safeRange.location

            // A freshly typed checkbox may not have its attachment attribute yet.
            if todoLocation == nil {
                let prefixLength = min(5, safeRange.length)
                let prefix = storage.mutableString.substring(
                    with: NSRange(location: safeRange.location, length: prefixLength)
                )
                if prefix == "- [ ]" || prefix == "- [x]" {
                    todoLocation = safeRange.location
                }
            }

            guard let todoLocation = todoLocation else { return false }

            let glyphRange = view.layoutManager.glyphRange(
                forCharacterRange: NSRange(location: todoLocation, length: 1),
                actualCharacterRange: nil
            )
            let todoRect = view.layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: view.textContainer
            )
            let expandedRect = CGRect(
                x: todoRect.origin.x - 50,
                y: todoRect.origin.y - 15,
                width: todoRect.width + 65,
                height: todoRect.height + 35
            )

            guard expandedRect.contains(point) else { return false }
            self.touchCharIndex = todoLocation
            return true
        }
        
        let text = view.textStorage.mutableString
        let currentLineRange = text.lineRange(for: NSRange(location: characterIndex, length: 0))
        
        if checkTodoInLine(lineRange: currentLineRange) {
            return true
        }
        
        if currentLineRange.location > 0 {
            let previousLineRange = text.lineRange(for: NSRange(location: currentLineRange.location - 1, length: 0))
            
            if checkTodoInLine(lineRange: previousLineRange) {
                return true
            }
        }
        
        return false
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let view = self.view as? EditTextView else { return }

        if self.state == .possible {
            for touch in touches {
                let point = touch.location(in: view)

                if isTodoTouch,
                   let initialTouchPoint,
                   hypot(point.x - initialTouchPoint.x, point.y - initialTouchPoint.y) > allowableTodoMovement {
                    self.state = .failed
                    view.isAllowedScrollRect = true
                    return
                }

                let characterIndex = view.layoutManager.characterIndex(for: point, in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
                self.touchCharIndex = characterIndex

                if view.isImage(at: characterIndex) {
                    self.state = .recognized
                    view.isAllowedScrollRect = true
                    return
                }

                if isTodoInTouchArea(point: point, characterIndex: characterIndex, view: view) {
                    self.state = .recognized
                    return
                }

                let glyphRect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: characterIndex, length: 1), in: view.textContainer)
                if glyphRect.contains(point) && view.isLink(at: characterIndex) {
                    self.state = .recognized
                    view.isAllowedScrollRect = true
                    return
                }
            }

            self.state = .failed
            view.isAllowedScrollRect = true
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if let view = self.view as? EditTextView {
            view.isAllowedScrollRect = true
        }
        // A discrete recognizer must leave .possible through .failed. Using
        // .cancelled here is only valid after a continuous gesture has begun.
        self.state = .failed
    }

    override func reset() {
        super.reset()
        initialTouchPoint = nil
        isTodoTouch = false
        touchCharIndex = nil
    }
}
