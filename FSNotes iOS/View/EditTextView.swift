//
//  EditTextView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class EditTextView: UITextView, UITextViewDelegate {
    private var undoIcon = UIImage(named: "undo.png")
    private var redoIcon = UIImage(named: "redo.png")
    
    public var typingFont: UIFont?
    public var currentFont: UIFont?
    
    public static var note: Note?
    
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
