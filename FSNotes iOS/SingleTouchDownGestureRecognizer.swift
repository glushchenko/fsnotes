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
                
                let characterIndex = view.layoutManager.characterIndex(for: touch.location(in: view), in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
                
                if view.isTodo(at: characterIndex) {
                    self.state = .recognized
                    return
                }

                if view.isImage(at: characterIndex) {
                    self.state = .possible
                    return
                }
            }

            self.state = .failed
        }

        print(self.state)
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
            }

            self.state = .failed
        }
    }
}
