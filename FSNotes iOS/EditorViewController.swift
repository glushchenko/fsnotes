//
//  EditorViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/31/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight
import Down

class EditorViewController: UIViewController, UITextViewDelegate {
    public var note: Note?
    
    private var isHighlighted: Bool = false
    private var downView: MarkdownView?
    
    @IBOutlet weak var editArea: EditTextView!
    
    override func viewDidLoad() {
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: MixedColor(normal: 0x000000, night: 0xfafafa)]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        
        if let n = note, n.isMarkdown() {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Preview", style: .done, target: self, action: #selector(preview))
        }
                
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
        
        if let n = note, n.isMarkdown() {
            self.navigationItem.rightBarButtonItem?.title = "Preview"
        }
        
        super.viewDidAppear(animated)
        
        if editArea.textStorage.length == 0 {
            editArea.perform(#selector(becomeFirstResponder), with: nil, afterDelay: 0.0)
        }
        
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController else {
            return
        }
        
        pageController.enableSwipe()
        
        // keyboard color
        if NightNight.theme == .night {
            editArea.keyboardAppearance = .dark
        } else {
            editArea.keyboardAppearance = .default
        }
        
        initLinksColor()
    }
    
    override var textInputMode: UITextInputMode? {
        let defaultLang = UserDefaultsManagement.defaultLanguage
        
        if UITextInputMode.activeInputModes.count - 1 >= defaultLang {
            return UITextInputMode.activeInputModes[defaultLang]
        }
        
        return super.textInputMode
    }
    
    public func fill(note: Note, preview: Bool = false) {
        self.note = note
        EditTextView.note = note
        
        UserDefaultsManagement.codeTheme = NightNight.theme == .night ? "monokai-sublime" : "atom-one-light"
        
        self.navigationItem.title = note.title
        
        UserDefaultsManagement.preview = false
        removeMdSubviewIfExist()
        
        if preview {
            loadPreview(note: note)
            return
        }
        
        guard editArea != nil else {
            return
        }
        
        editArea.initUndoRedoButons()
        
        if note.isRTF() {
            view.backgroundColor = UIColor.white
            editArea.backgroundColor = UIColor.white
        } else {
            view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x2e2c32)
            editArea.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x2e2c32)
        }
        
        if note.type == .PlainText {
            let foregroundColor = NightNight.theme == .night ? UIColor.white : UIColor.black
            editArea.attributedText = NSAttributedString(string: note.content.string, attributes: [NSAttributedStringKey.foregroundColor: foregroundColor])
        } else {
            editArea.attributedText = note.content
        }
        
        if note.isMarkdown() {
            editArea.textStorage.updateFont()
            
            NotesTextProcessor.fullScan(note: note, storage: editArea.textStorage, range: NSRange(0..<editArea.textStorage.length), async: true)
        }
        
        editArea.delegate = self
        
        let cursor = editArea.selectedTextRange
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        let storage = editArea.textStorage
        let width = editArea.frame.width
        let range = NSRange(0..<storage.length)
        
        if UserDefaultsManagement.liveImagesPreview {
            let processor = ImagesProcessor(styleApplier: storage, range: range, maxWidth: width, note: note)
            processor.load()
        }
        
        let search = getSearchText()
        if search.count > 0 {
            let processor = NotesTextProcessor(storage: storage)
            processor.highlightKeyword(search: search)
            isHighlighted = true
        }
        
        editArea.selectedTextRange = cursor
        
        switch note.type {
        case .PlainText:
            editArea.font = UserDefaultsManagement.noteFont
        case .RichText:
            break
        case .Markdown:
            return
        }
    }
    
    func loadPreview(note: Note) {
        let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)
        let markdownString = note.getPrettifiedContent()
        
        do {
            guard let imagesStorage = note.project?.url else { return }
            
            if let downView = try? MarkdownView(imagesStorage: imagesStorage, frame: self.view.frame, markdownString: markdownString, css: "", templateBundle: bundle) {
                downView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(downView)
            }
        }
        return
    }
    
    func refill() {
        initLinksColor()
        
        if let note = self.note {
            let keyboardIsOpen = editArea.isFirstResponder
            
            if keyboardIsOpen {
                editArea.endEditing(true)
            }
            
            if NightNight.theme == .night {
                editArea.keyboardAppearance = .dark
            } else {
                editArea.keyboardAppearance = .default
            }
            
            fill(note: note)
        }
    }
    
    public func reloadPreview() {
        if UserDefaultsManagement.preview, let note = self.note {
            removeMdSubviewIfExist(reload: true, note: note)
        }
    }
    
    // RTF style completions
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let note = self.note else {
            return true
        }
        
        // Paste in UITextView
        if note.isMarkdown() && text == UIPasteboard.general.string {
            self.editArea.insertText(text)
            NotesTextProcessor.fullScan(note: note, storage: editArea.textStorage, range: NSRange(0..<editArea.textStorage.length), async: true)
            return false
        }
        
        if text == "\n" {
            self.editArea.insertText("\n")
            let formatter = TextFormatter(textView: self.editArea, note: note)
            formatter.newLine()
            return false
        }
        
        guard note.isRTF() else { return true }
        
        var i = 0
        let length = editArea.selectedRange.length
        
        if length > 0 {
            i = editArea.selectedRange.location
        } else if editArea.selectedRange.location != 0 {
            i = editArea.selectedRange.location - 1
        }
        
        guard i > 0 else { return true }
    
        let upper = editArea.selectedRange.upperBound
        let substring = editArea.attributedText.attributedSubstring(from: NSRange(i..<upper))
        var typingFont = substring.attribute(.font, at: 0, effectiveRange: nil)
        
        if let font = editArea.typingFont {
            typingFont = font
            editArea.typingFont = nil
        }

        editArea.typingAttributes[NSAttributedStringKey.font.rawValue] = typingFont
        editArea.currentFont = typingFont as? UIFont
        
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageController.orderedViewControllers[0] as? ViewController else {
                return
        }
        
        vc.cloudDriveManager?.cloudDriveQuery.disableUpdates()
        
        guard let note = self.note else {
            return
        }
        
        if isHighlighted {
            let search = getSearchText()
            let processor = NotesTextProcessor(storage: textView.textStorage)
            processor.highlightKeyword(search: search, remove: true)
            isHighlighted = false
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
        note.save(needImageUnLoad: true)
        
        if var font = UserDefaultsManagement.noteFont {
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font)
            }
            editArea.typingAttributes[NSAttributedStringKey.font.rawValue] = font
        }
        
        editArea.initUndoRedoButons()
        
        vc.cloudDriveManager?.cloudDriveQuery.enableUpdates()
    }
    
    func getSearchText() -> String {
        if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[0] as? ViewController, let search = viewController.search.text {
            return search
        }
        
        return ""
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            self.view.frame.size.height = UIScreen.main.bounds.height
            self.view.frame.size.height -= keyboardSize.height
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        self.view.frame.size.height = UIScreen.main.bounds.height
    }
    
    func addToolBar(textField: UITextView){
        let toolBar = UIToolbar()
        toolBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        
        toolBar.isTranslucent = true
        toolBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)

        let boldButton = UIBarButtonItem(image: #imageLiteral(resourceName: "bold.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.boldPressed))
        let italicButton = UIBarButtonItem(image: #imageLiteral(resourceName: "italic.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.italicPressed))
        let indentButton = UIBarButtonItem(image: #imageLiteral(resourceName: "indent.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.indentPressed))
        let unindentButton = UIBarButtonItem(image: #imageLiteral(resourceName: "unindent.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.unIndentPressed))
        let headerButton = UIBarButtonItem(image: #imageLiteral(resourceName: "header.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.headerPressed))
        let undoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "undo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.undoPressed))
        let redoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "redo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.redoPressed))
        
        
        let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(EditorViewController.donePressed))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([boldButton, italicButton, indentButton, unindentButton, headerButton, spaceButton, undoButton, redoButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        toolBar.sizeToFit()
        
        textField.delegate = self
        textField.inputAccessoryView = toolBar
        
        if let etv = textField as? EditTextView {
            etv.initUndoRedoButons()
        }
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
            formatter.header("#")
        }
    }
    
    @objc func donePressed(){
        view.endEditing(true)
    }
    
    @objc func cancelPressed(){
        view.endEditing(true)
    }
    
    @objc func preferredContentSizeChanged() {
        if let n = note {
            self.fill(note: n)
        }
    }
    
    @objc func undoPressed() {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageController.orderedViewControllers[1] as? UINavigationController,
            let evc = vc.viewControllers[0] as? EditorViewController,
            let ea = evc.editArea,
            let um = ea.undoManager else {
                return
        }
        
        um.undo()
        ea.initUndoRedoButons()
    }
    
    @objc func redoPressed() {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageController.orderedViewControllers[1] as? UINavigationController,
            let evc = vc.viewControllers[0] as? EditorViewController,
            let ea = evc.editArea,
            let um = ea.undoManager else {
                return
        }
        
        um.redo()
        ea.initUndoRedoButons()
    }
    
    @objc func preview() {
        let isPreviewMode = !UserDefaultsManagement.preview
        
        guard let n = note else {
            return
        }
        
        if isPreviewMode {
            view.endEditing(true)
        }
        
        navigationItem.rightBarButtonItem?.title = isPreviewMode ? "Edit" : "Preview"
        
        fill(note: n, preview: isPreviewMode)
        UserDefaultsManagement.preview = isPreviewMode
    }
    
    func removeMdSubviewIfExist(reload: Bool = false, note: Note? = nil) {
        guard view.subviews.indices.contains(1) else {
            return
        }
        
        DispatchQueue.main.async {
            for sub in self.view.subviews {
                if sub.isKind(of: MarkdownView.self) {
                    sub.removeFromSuperview()
                }
            }
            
            if reload, let note = note {
                self.loadPreview(note: note)
            }
        }
    }
    
    func initLinksColor() {
        let linkAttributes: [String : Any] = [
            NSAttributedStringKey.foregroundColor.rawValue: NightNight.theme == .night ? UIColor(red:0.49, green:0.92, blue:0.63, alpha:1.0) : UIColor(red:0.24, green:0.51, blue:0.89, alpha:1.0),
            NSAttributedStringKey.underlineColor.rawValue: UIColor.lightGray,
            NSAttributedStringKey.underlineStyle.rawValue: NSUnderlineStyle.styleNone.rawValue]
        
        if editArea != nil {
            editArea.linkTextAttributes = linkAttributes
        }
    }

}
