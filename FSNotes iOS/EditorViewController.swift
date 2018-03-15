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
        
        addToolBar(textField: editArea)
        
        guard let pageController = self.parent as? PageViewController else {
            return
        }
        
        pageController.enableSwipe()
        
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        editArea.isScrollEnabled = true
        super.viewDidAppear(animated)
        
        if editArea.textStorage.length == 0 {
            editArea.perform(#selector(becomeFirstResponder), with: nil, afterDelay: 0.0)
        }
        
        height = editArea.frame.size.height
    }
    
    override var textInputMode: UITextInputMode? {
        guard let defaultLang = UserDefaultsManagement.defaultLanguage else {
            return super.textInputMode
        }
        
        for tim in UITextInputMode.activeInputModes {
            if tim.primaryLanguage == defaultLang {
                return tim
            }
        }
        
        return super.textInputMode
    }
    
    private var height: CGFloat = 0.0
    
    public func fill(note: Note) {
        self.note = note
        note.markdownCache()
        
        guard editArea != nil else {
            return
        }
        
        editArea.isScrollEnabled = false
        editArea.delegate = self
        let cursor = editArea.selectedTextRange
        
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
        editArea.selectedTextRange = cursor
        
        switch note.type {
        case .PlainText:
            editArea.font = UserDefaultsManagement.noteFont
        case .RichText:
            storage.updateFont()
        case .Markdown:
            return
        }
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
        
        if var font = UserDefaultsManagement.noteFont {
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font)
            }
            editArea.typingAttributes[NSAttributedStringKey.font.rawValue] = font
        }
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            editArea.frame.size.height = height - keyboardSize.height
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        editArea.frame.size.height = height
    }
    
    func addToolBar(textField: UITextView){
        let toolBar = UIToolbar()
        toolBar.barStyle = UIBarStyle.default
        toolBar.isTranslucent = true
        toolBar.tintColor = UIColor(red: 76/255, green: 217/255, blue: 100/255, alpha: 1)
        

        let boldButton = UIBarButtonItem(image: #imageLiteral(resourceName: "bold.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.boldPressed))
        let italicButton = UIBarButtonItem(image: #imageLiteral(resourceName: "italic.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.italicPressed))
        let indentButton = UIBarButtonItem(image: #imageLiteral(resourceName: "indent.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.indentPressed))
        let unindentButton = UIBarButtonItem(image: #imageLiteral(resourceName: "unindent.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.unIndentPressed))
        let headerButton = UIBarButtonItem(image: #imageLiteral(resourceName: "header.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.headerPressed))
        
        let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(EditorViewController.donePressed))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([boldButton, italicButton, indentButton, unindentButton, headerButton, spaceButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        toolBar.sizeToFit()
        
        textField.delegate = self
        textField.inputAccessoryView = toolBar
    }
    
    @objc func boldPressed(){
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.bold()
        }
    }
    
    @objc func italicPressed(){
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.italic()
        }
    }
    
    @objc func indentPressed(){
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.tab()
        }
    }
    
    @objc func unIndentPressed(){
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.unTab()
        }
    }
    
    @objc func headerPressed() {
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.header()
        }
    }
    
    @objc func donePressed(){
        view.endEditing(true)
    }
    
    @objc func cancelPressed(){
        view.endEditing(true) // or do something
    }
    
    @objc func preferredContentSizeChanged() {
        if let n = note {
            self.fill(note: n)
        }
    }
}
