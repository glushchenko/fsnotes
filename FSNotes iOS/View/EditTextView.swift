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
    private var undoIcon = UIImage(named: "undo.png")
    private var redoIcon = UIImage(named: "redo.png")
    
    public var typingFont: UIFont?
    public var currentFont: UIFont?
    
    public static var note: Note?
    
    override func cut(_ sender: Any?) {
        if self.textStorage.length > self.selectedRange.upperBound {
            let attributedString = self.textStorage.attributedSubstring(from: self.selectedRange)
            var item = [kUTTypeUTF8PlainText as String : attributedString.string as Any]
            
            if let rtf = try? attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes:
                [NSAttributedString.DocumentAttributeKey.documentType:NSAttributedString.DocumentType.rtfd]) {
                item[kUTTypeFlatRTFD as String] = rtf
            }
            
            UIPasteboard.general.items = [item]
        }

        super.cut(sender)
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
        
        if let toolBar = self.inputAccessoryView as? UIToolbar, let items = toolBar.items {
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
}
