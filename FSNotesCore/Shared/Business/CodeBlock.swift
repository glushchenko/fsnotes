//
//  CodeBlock.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 8/28/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import AppKit

class CodeBlock: NSTextBlock {
    override init() {
        super.init()
        setWidth(6, type: .absoluteValueType, for: .margin)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func drawBackground(withFrame frameRect: NSRect, in controlView: NSView, characterRange charRange: NSRange, layoutManager: NSLayoutManager) {

        let adjustedFrame = CGRect(x: frameRect.origin.x,
                                   y: frameRect.origin.y + 2,
                                   width: controlView.frame.size.width - (frameRect.origin.x * 2),
                                   height: frameRect.size.height - 2)

        let selectionPath = NSBezierPath.init(roundedRect: adjustedFrame, xRadius: 5, yRadius: 5)

        NotesTextProcessor.codeBackground.setFill()
        selectionPath.fill()

        super.drawBackground(withFrame: adjustedFrame, in: controlView, characterRange: charRange, layoutManager: layoutManager)
    }

    override func rectForLayout(at startingPoint: NSPoint, in rect: NSRect, textContainer: NSTextContainer, characterRange charRange: NSRange) -> NSRect {
        var res = super.rectForLayout(at: startingPoint, in: rect, textContainer: textContainer, characterRange: charRange)
        res.size.width = rect.size.width
        return res
    }
}
