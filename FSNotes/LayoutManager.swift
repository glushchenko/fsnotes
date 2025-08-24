//
//  CustomLayoutManager.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 24.08.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

class LayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        guard let textView = firstTextView as? EditTextView,
              let font = textView.font,
              textView.selectedRange().length > 0 else {
            return
        }

        let selectedGlyphRange = glyphRange(forCharacterRange: textView.selectedRange(), actualCharacterRange: nil)
        guard selectedGlyphRange.length > 0 else {
            return
        }

        let selectionColor = NSColor.systemBlue.withAlphaComponent(0.20)
        selectionColor.setFill()

        let lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        let lineWidth = textView.frame.width - textView.getInsetWidth() * 2

        var lastLineRect: NSRect = .zero
        if let textContainer = textView.textContainer {
            let totalGlyphRange = self.glyphRange(for: textContainer)
            if totalGlyphRange.length > 0 {
                let lastGlyphIndex = totalGlyphRange.location + totalGlyphRange.length - 1
                lastLineRect = self.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
            }
        }
        
        enumerateLineFragments(forGlyphRange: selectedGlyphRange) { (lineRect, _, container, glyphRange, stop) in
            let intersection = NSIntersectionRange(glyphRange, selectedGlyphRange)
            guard intersection.length > 0 else { return }
        
            let rect = self.calculateHighlightRect(
                intersection: intersection,
                container: container,
                lineRect: lineRect,
                origin: origin,
                font: font,
                lineSpacing: lineSpacing,
                lineWidth: lineWidth,
                isLastLine: lineRect == lastLineRect
            )
            
            let path = NSBezierPath(rect: rect)
            path.fill()
        }

        DispatchQueue.main.async {
            textView.setNeedsDisplay(textView.bounds)
        }
    }

    private func calculateHighlightRect(
        intersection: NSRange,
        container: NSTextContainer,
        lineRect: NSRect,
        origin: CGPoint,
        font: NSFont,
        lineSpacing: CGFloat,
        lineWidth: CGFloat,
        isLastLine: Bool
    ) -> NSRect {
        var rect = self.boundingRect(forGlyphRange: intersection, in: container)
        rect.origin.x += origin.x
        rect.origin.y += origin.y
        
        let baseline = lineRect.origin.y + origin.y + font.ascender
        let offset = (baseline - font.capHeight) - lineSpacing / 2 - 3
        
        rect.origin.y = offset
        rect.size.height = lineRect.height

        if isLastLine {
            rect.size.height += 10
        }
        
        let lineGlyphRange = self.glyphRange(forBoundingRect: lineRect, in: container)
        if intersection.upperBound >= lineGlyphRange.upperBound && !isLastLine {
            rect.size.width = lineWidth
        }
        
        return rect
    }
    
    func layoutManager(_ layoutManager: NSLayoutManager,
                           paragraphSpacingBeforeGlyphAt glyphIndex: Int,
                       withProposedLineFragmentRect rect: NSRect) -> CGFloat {
    
        return glyphIndex == 0 ? 4 : 0
    }
}

