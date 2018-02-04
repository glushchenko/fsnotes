//
//  EditorViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/31/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class EditorViewController: UIViewController, UITextViewDelegate {
    public var note: Note?
    
    @IBOutlet weak var editArea: UITextView!
    
    override func viewDidLoad() {
        guard let note = self.note else {
            return
        }
        
        fill(note: note)
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        editArea.isScrollEnabled = true
        super.viewDidAppear(animated)
        
        if editArea.textStorage.length == 0 {
            editArea.perform(#selector(becomeFirstResponder), with: nil, afterDelay: 0.0)
        }
    }
    
    private var height: CGFloat = 0.0
    
    public func fill(note: Note) {
        self.note = note
        
        guard editArea != nil else {
            return
        }
        
        editArea.isScrollEnabled = false
        editArea.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        editArea.attributedText = note.content
        
        let storage = editArea.textStorage
        let width = editArea.frame.width
        let range = NSRange(0..<storage.length)
        
        let processor = ImagesProcessor(styleApplier: storage, range: range, maxWidth: width, note: note)
        processor.load()
        
        editArea.scrollRangeToVisible(NSRange(location:0, length:0))
        height = editArea.frame.size.height
    }
        
    func textViewDidChange(_ textView: UITextView) {
        guard let note = self.note else {
            return
        }
    
        let range = editArea.selectedRange
        let storage = editArea.textStorage
        let width = editArea.frame.width
        
        let processor = NotesTextProcessor(note: note, storage: storage, range: range, maxWidth: width)
        
        if note.type == .PlainText || note.type == .RichText {
            processor.higlightLinks()
        } else {
            processor.scanParagraph()
        }
        
        note.content = NSMutableAttributedString(attributedString: editArea.attributedText)
        note.save()
    }
    
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            editArea.frame.size.height = height - keyboardSize.height
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        editArea.frame.size.height = height
    }
    
}
