//
//  EditTextView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import MobileCoreServices

class EditTextView: UITextView, UITextViewDelegate {

    public var isAllowedScrollRect = true

    private var undoIcon = UIImage(named: "undo.png")
    private var redoIcon = UIImage(named: "redo.png")

    public var typingFont: UIFont?
    public static var note: Note?
    public var lasTouchPoint: CGPoint?

    override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        if self.isAllowedScrollRect {
            super.scrollRectToVisible(rect, animated: animated)
        }
    }
    
    override func cut(_ sender: Any?) {
        guard let note = EditTextView.note else {
            super.cut(sender)
            return
        }

        let attributedString = self.textStorage.attributedSubstring(from: self.selectedRange)

        let pathKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.path")
        if self.selectedRange.length == 1, let path = attributedString.attribute(pathKey, at: 0, effectiveRange: nil) as? String,
            let imageUrl = note.getImageUrl(imageName: path),
            let data = try? Data(contentsOf: imageUrl),
            let image = UIImage(data: data),
            let jpgData = UIImageJPEGRepresentation(image, 1) {

            let location = selectedRange.location

            if let textRange = getTextRange() {
                self.replace(textRange, withText: "")
            }

            self.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: location, length: 1))
            self.selectedRange = NSRange(location: location, length: 0)

            UIPasteboard.general.setData(jpgData, forPasteboardType: "public.jpeg")
            return
        }

        if self.textStorage.length > self.selectedRange.upperBound {
            if let rtfd = try? attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType:NSAttributedString.DocumentType.rtfd]) {

                let item = [kUTTypeFlatRTFD as String : rtfd]
                UIPasteboard.general.addItems([item])

                return
            }

            let item = [kUTTypeUTF8PlainText as String : attributedString.string as Any]
            UIPasteboard.general.items = [item]
        }

        super.cut(sender)
    }

    override func paste(_ sender: Any?) {
        guard let note = EditTextView.note else {
            super.paste(sender)
            return
        }

        for item in UIPasteboard.general.items {
            if let rtfd = item["com.apple.flat-rtfd"] as? Data {
                if let attributedString = try? NSAttributedString(data: rtfd, options: [NSAttributedString.DocumentReadingOptionKey.documentType : NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {

                    let location = selectedRange.location
                    self.textStorage.insert(attributedString, at: selectedRange.location)
                    self.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: location, length: 1))

                    note.content = NSMutableAttributedString(attributedString: self.attributedText)
                    note.save()
                    UIApplication.getEVC().refill()

                    return
                }
            }

            if let image = item["public.jpeg"] as? UIImage, let data = UIImageJPEGRepresentation(image, 1) {
                if let string = ImagesProcessor.writeImage(data: data, note: note) {
                    let path = note.getMdImagePath(name: string)
                    if let imageUrl = note.getImageUrl(imageName: path) {
                        let range = NSRange(location: selectedRange.location, length: 1)
                        let attachment = ImageAttachment(title: "", path: path, url: imageUrl, cache: nil, invalidateRange: range)

                        if let attributedString = attachment.getAttributedString() {
                            self.insertText(" ")
                            self.textStorage.replaceCharacters(in: range, with: attributedString)
                            return
                        }
                    }
                }
            }
        }

        super.paste(sender)
    }

    override func copy(_ sender: Any?) {
        guard let note = EditTextView.note else {
            super.copy(sender)
            return
        }

        let attributedString = self.textStorage.attributedSubstring(from: self.selectedRange)

        let pathKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.path")
        if self.selectedRange.length == 1, let path = attributedString.attribute(pathKey, at: 0, effectiveRange: nil) as? String {

            DispatchQueue.global().async {
                if let imageUrl = note.getImageUrl(imageName: path),
                    let data = try? Data(contentsOf: imageUrl),
                    let image = UIImage(data: data),
                    let jpgData = UIImageJPEGRepresentation(image, 1) {

                    UIPasteboard.general.setData(jpgData, forPasteboardType: "public.jpeg")
                }
            }

            return
        }

        if self.textStorage.length >= self.selectedRange.upperBound {
            if let rtfd = try? attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType:NSAttributedString.DocumentType.rtfd]) {

                UIPasteboard.general.setData(rtfd, forPasteboardType: kUTTypeFlatRTFD as String)
            }
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
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageController.orderedViewControllers[1] as? UINavigationController,
            let evc = vc.viewControllers[0] as? EditorViewController,
            let ea = evc.editArea,
            let um = ea.undoManager else {
                return
        }
        
        let img = um.canUndo ? undoIcon : undoIcon?.alpha(0.5)
        let redoImg = um.canRedo ? redoIcon : redoIcon?.alpha(0.5)

        if let scroll = self.inputAccessoryView as? UIScrollView, let toolBar = scroll.subviews.first as? UIToolbar, let items = toolBar.items {
            for item in items {
                
                if item.action == #selector(EditorViewController.undoPressed) {
                    item.image = img
                }
                
                if item.action == #selector(EditorViewController.redoPressed) {
                    item.image = redoImg
                }
            }
        }
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
        let storage = self.textStorage

        let pathKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.path")

        if storage.length > location, storage.attribute(pathKey, at: location, effectiveRange: nil) != nil {
            return true
        }

        return false
    }

    public func isLink(at location: Int) -> Bool {
        let storage = self.textStorage

        if storage.length > location, storage.attribute(.link, at: location, effectiveRange: nil) != nil {
            return true
        }

        return false
    }
}
