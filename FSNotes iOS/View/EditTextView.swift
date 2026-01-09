//
//  EditTextView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class EditTextView: UITextView, UITextViewDelegate {

    public var textStorageProcessor: TextStorageProcessor?
    
    public var isFillAction = false
    public var isAllowedScrollRect: Bool?
    public var typingFont: UIFont?
    public var note: Note?
    public var lasTouchPoint: CGPoint?
    public var imagesLoaderQueue = OperationQueue.init()
    public var keyboardIsOpened = true
    public var callCounter = 0
    
    required init?(coder: NSCoder) {
        if #available(iOS 13.2, *) {
            super.init(coder: coder)
        }
        else {
            super.init(frame: .zero, textContainer: nil)
            self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.contentMode = .scaleToFill

            self.isScrollEnabled = false   // causes expanding height

            // Auto Layout
            self.translatesAutoresizingMaskIntoConstraints = false
            self.font = UIFont(name: "HelveticaNeue", size: 18)
        }

        autocorrectionType = UserDefaultsManagement.editorAutocorrection ? .yes : .no
        spellCheckingType = UserDefaultsManagement.editorSpellChecking ? .yes : .no
    }

    override func becomeFirstResponder() -> Bool {
        textStorage.removeHighlight()
        
        return super.becomeFirstResponder()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if !isFirstResponder && window != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                
                if !self.isFirstResponder && self.window != nil {
                    _ = self.becomeFirstResponder()
                }
            }
        }
    }

    public func initTextStorage() {
        let processor = TextStorageProcessor()
        processor.editor = self
        
        textStorageProcessor = processor
        textStorage.delegate = processor
    }

    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        let selectionRects = super.selectionRects(for: range)

        let fontHeight = UserDefaultsManagement.noteFont.lineHeight
        let lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        let endCharacterIndex = offset(from: beginningOfDocument, to: range.end)
        let endParRange = textStorage.mutableString.paragraphRange(for: NSRange(location: endCharacterIndex, length: 0))

        var lastWideRect: UITextSelectionRect?
        if selectionRects.count > 2 {
            lastWideRect = selectionRects[selectionRects.count - 3]
        }

        var result = [UITextSelectionRect]()
        for selectionRect in selectionRects {
            if selectionRect.rect.width == 0 {
                let customRect = CGRect(x: selectionRect.rect.origin.x, y: selectionRect.rect.origin.y - lineSpacing / 2, width: 0, height: fontHeight + lineSpacing)
                let sel = EditorSelectionRect(originalRect: selectionRect, rect: customRect)
                result.append(sel)
            } else {
                var heightOffset = CGFloat(0)

                if endParRange.upperBound == textStorage.length && lastWideRect == selectionRect {
                    heightOffset += lineSpacing
                }

                let customRect = CGRect(x: selectionRect.rect.origin.x, y: selectionRect.rect.origin.y - lineSpacing / 2, width: selectionRect.rect.width, height: selectionRect.rect.height + heightOffset)

                let selectionRect = EditorSelectionRect(originalRect: selectionRect, rect: customRect)
                result.append(selectionRect)
            }
        }

        return result
    }

    override func caretRect(for position: UITextPosition) -> CGRect {
        let characterIndex = offset(from: beginningOfDocument, to: position)

        guard layoutManager.isValidGlyphIndex(characterIndex) else {
            return super.caretRect(for: position)
        }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
        let usedLineFragment = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)

        guard !usedLineFragment.isEmpty else {
            return super.caretRect(for: position)
        }

        var caretRect = super.caretRect(for: position)
        caretRect.origin.y = usedLineFragment.origin.y + textContainerInset.top
        caretRect.size.height = usedLineFragment.size.height - CGFloat(UserDefaultsManagement.editorLineSpacing) / 2

        return caretRect
    }

    override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        guard isAllowedScrollRect == true else { return }

        callCounter += 1

        if keyboardIsOpened {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.8, delay: 0, options: .beginFromCurrentState, animations: {
                    super.scrollRectToVisible(rect, animated: false)
                })
            }

            if callCounter > 2 {
                keyboardIsOpened = false
                callCounter = 0
            }
        } else {
            super.scrollRectToVisible(rect, animated: animated)
        }
    }

    override func cut(_ sender: Any?) {
        let selectedRange = self.selectedRange
        guard selectedRange.length > 0 else { return }

        let selectedString = textStorage.attributedSubstring(from: selectedRange)
        let attributedString = NSMutableAttributedString(attributedString: selectedString).unloadTasks()
        attributedString.saveData()

        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: attributedString,
                requiringSecureCoding: false
            )

            UIPasteboard.general.setItems([
                [UIPasteboard.attributed: data],
                [UTType.plainText.identifier: attributedString.string]
            ])
        } catch {
            print("Serialization error: \(error)")
        }

        if let should = delegate?.textView?(self, shouldChangeTextIn: selectedRange, replacementText: "") {
            guard should else { return }
        }

        let empty = NSAttributedString(string: "")
        self.insertAttributedText(empty)
    }


    override func paste(_ sender: Any?) {
        let pb = UIPasteboard.general
        var toInsert: NSAttributedString?

        if let imageData = pb.data(forPasteboardType: UTType.png.identifier) ??
                           pb.data(forPasteboardType: UTType.jpeg.identifier) ??
                           pb.data(forPasteboardType: UTType.image.identifier) {

            toInsert = NSMutableAttributedString.build(data: imageData)
        }

        else if let data = pb.data(forPasteboardType: UIPasteboard.attributed) {
            do {
                if let attributed = try NSKeyedUnarchiver.unarchivedObject(
                    ofClass: NSAttributedString.self,
                    from: data
                ) {
                    let mutable = NSMutableAttributedString(attributedString: attributed)
                    mutable.loadTasks()
                    toInsert = mutable
                }
            } catch {
                print("Paste error: \(error)")
            }
        }

        else if let plain = pb.string {
            let mutable = NSMutableAttributedString(string: plain)
            mutable.loadTasks()
            toInsert = mutable
        }

        guard let attrToInsert = toInsert else {
            super.paste(sender)
            return
        }

        let range = self.selectedRange
        if let should = delegate?.textView?(self, shouldChangeTextIn: range, replacementText: attrToInsert.string), !should {
            return
        }

        self.insertAttributedText(attrToInsert)
    }

    override func copy(_ sender: Any?) {
        guard selectedRange.length > 0 else { return }

        let selectedString = textStorage.attributedSubstring(from: self.selectedRange)
        
        let attributedString = NSMutableAttributedString(attributedString: selectedString).unloadTasks()
        attributedString.saveData()

        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: attributedString,
                requiringSecureCoding: false
            )

            UIPasteboard.general.setItems([
                [UIPasteboard.attributed: data],
                [UTType.plainText.identifier: attributedString.string]
            ])

            return
        } catch {
            print("Serialization error: \(error)")
        }

        super.copy(sender)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.paste(_:)) {
            return true
        }

        return super.canPerformAction(action, withSender: sender)
    }
    
    public func initUndoRedoButons() {
        UIApplication.getEVC().undoBarButton?.isEnabled = undoManager?.canUndo == true
        UIApplication.getEVC().redoBarButton?.isEnabled = undoManager?.canRedo == true
    }
    
    public func isTodo(at location: Int) -> Bool {
        let storage = self.textStorage
        
        if storage.length > location, storage.attribute(.todo, at: location, effectiveRange: nil) != nil {
            return true
        }
        
        let range = (storage.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
        let string = storage.attributedSubstring(from: range).string as NSString
        
        var length = string.range(of: "- [ ]").length
        if length == 0 {
            length = string.range(of: "- [x]").length
        }
        
        if length > 0 {
            let upper = range.location + length
            if location >= range.location && location <= upper {
                return true
            }
        }
        
        return false
    }

    public func isImage(at location: Int) -> Bool {
        return textStorage.getMeta(at: location) != nil
    }

    public func isLink(at location: Int) -> Bool {
        let storage = self.textStorage

        if storage.length > location, storage.attribute(.link, at: location, effectiveRange: nil) != nil {
            return true
        }

        return false
    }

    public func isWikiLink(at location: Int) -> Bool {
        let storage = self.textStorage

        if storage.length > location, let path = storage.attribute(.link, at: location, effectiveRange: nil) as? String, path.starts(with: "fsnotes://find?id=") {
            return true
        }

        return false
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard traitCollection.hasDifferentColorAppearance(
            comparedTo: previousTraitCollection
        ) else { return }

        NotesTextProcessor.hl = nil
        
        UIApplication.getEVC().refill()
    }
}

struct Undo {
    var range: NSRange
    var string: NSAttributedString
}
