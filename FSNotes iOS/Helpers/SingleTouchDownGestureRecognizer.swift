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
                let characterIndex = view.layoutManager.characterIndex(for: point, in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
                self.touchCharIndex = characterIndex

                if UIMenuController.shared.isMenuVisible {
                    UIMenuController.shared.hideMenu(from: view)
                }

                let glyphIndex = view.layoutManager.glyphIndex(for: point, in: view.textContainer)

                if isTodoInTouchArea(point: point, characterIndex: characterIndex, view: view) && (self.selectedRange?.isEmpty == true || !view.isFirstResponder) {
                    self.state = .recognized
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

    private func isTodoInTouchArea(point: CGPoint, characterIndex: Int, view: EditTextView) -> Bool {
        if view.isTodo(at: characterIndex) {
            return true
        }
        
        func checkTodoInLine(lineRange: NSRange) -> Bool {
            for i in lineRange.location..<min(lineRange.location + lineRange.length, view.textStorage.length) {
                if view.isTodo(at: i) {
                    let glyphRange = view.layoutManager.glyphRange(forCharacterRange: NSRange(location: i, length: 1), actualCharacterRange: nil)
                    let todoRect = view.layoutManager.boundingRect(forGlyphRange: glyphRange, in: view.textContainer)
                    
                    let expandedRect = CGRect(
                        x: todoRect.origin.x - 50,
                        y: todoRect.origin.y - 15,
                        width: todoRect.width + 65,
                        height: todoRect.height + 35
                    )
                    
                    if expandedRect.contains(point) {
                        self.touchCharIndex = i
                        return true
                    }
                    
                    break
                }
            }
            return false
        }
        
        let currentLineRange = (view.text as NSString).lineRange(for: NSRange(location: characterIndex, length: 0))
        
        if checkTodoInLine(lineRange: currentLineRange) {
            return true
        }
        
        if currentLineRange.location > 0 {
            let previousLineRange = (view.text as NSString).lineRange(for: NSRange(location: currentLineRange.location - 1, length: 0))
            
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
}
