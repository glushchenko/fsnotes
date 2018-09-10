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
import AudioToolbox
import DKImagePickerController
import MobileCoreServices
import Photos
import GSImageViewerController

class EditorViewController: UIViewController, UITextViewDelegate {
    public var note: Note?
    
    private var isHighlighted: Bool = false
    private var downView: MarkdownView?
    private var isUndo = false
    private let storageQueue = OperationQueue()
    private var toolbar: Toolbar = .markdown

    @IBOutlet weak var editArea: EditTextView!
    
    override func viewDidLoad() {
        storageQueue.maxConcurrentOperationCount = 1
        
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: MixedColor(normal: 0x000000, night: 0xfafafa)]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        
        if let n = note, n.isMarkdown() {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Preview", style: .done, target: self, action: #selector(preview))
        }
        
        let tap = SingleTouchDownGestureRecognizer(target: self, action: #selector(tapHandler(_:)))
        self.editArea.addGestureRecognizer(tap)
        
        super.viewDidLoad()
        
        self.addToolBar(textField: editArea, toolbar: self.getMarkdownToolbar())
        
        guard let pageController = self.parent as? PageViewController else {
            return
        }
        
        pageController.enableSwipe()
        
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
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
        
        self.configureFont()
        self.configureToolbar()

        editArea.textStorage.updateFont()
        
        if note.isMarkdown() {
            NotesTextProcessor.fullScan(note: note, storage: editArea.textStorage, range: NSRange(0..<editArea.textStorage.length), async: true)
        }
        
        editArea.delegate = self
        
        let cursor = editArea.selectedTextRange
        let storage = editArea.textStorage
        let range = NSRange(0..<storage.length)

        if UserDefaultsManagement.liveImagesPreview {
            let processor = ImagesProcessor(styleApplier: storage, range: range, note: note)
            processor.load()
        }

        if note.isMarkdown() {
            while (editArea.textStorage.mutableString.contains("- [ ] ")) {
                let range = editArea.textStorage.mutableString.range(of: "- [ ] ")
                if editArea.textStorage.length >= range.upperBound, let unChecked = AttributedBox.getUnChecked() {
                    editArea.textStorage.replaceCharacters(in: range, with: unChecked)
                }
            }

            while (editArea.textStorage.mutableString.contains("- [x] ")) {
                let range = editArea.textStorage.mutableString.range(of: "- [x] ")
                if editArea.textStorage.length >= range.upperBound, let checked = AttributedBox.getChecked() {
                    editArea.textStorage.replaceCharacters(in: range, with: checked)
                }
            }
        }

        let search = getSearchText()
        if search.count > 0 {
            let processor = NotesTextProcessor(storage: storage)
            processor.highlightKeyword(search: search)
            isHighlighted = true
        }
        
        editArea.selectedTextRange = cursor

        if note.type != .RichText {

            editArea.typingAttributes[NSAttributedStringKey.font.rawValue] = UIFont.bodySize()
            return
        }

        editArea.applyLeftParagraphStyle()
    }

    private func configureToolbar() {
        guard let note = self.note else { return }

        if note.type == .PlainText {
            if self.toolbar != .plain {
                self.toolbar = .plain
                self.addToolBar(textField: editArea, toolbar: self.getPlainTextToolbar())
            }
            return
        }

        if note.type == .RichText {
            if self.toolbar != .rich {
                self.toolbar = .rich
                self.addToolBar(textField: editArea, toolbar: self.getRTFToolbar())
            }
            return
        }

        if self.toolbar != .markdown {
            self.toolbar = .markdown
            self.addToolBar(textField: editArea, toolbar: getMarkdownToolbar())
        }
    }
    
    public func configureFont() {
        if let note = self.note, note.type != .RichText {
            self.editArea.textStorage.addAttribute(.font, value: UIFont.bodySize(), range: NSRange(0..<self.editArea.textStorage.length))
        }

        self.editArea.typingAttributes.removeAll()
        self.editArea.typingAttributes[NSAttributedStringKey.font.rawValue] = UIFont.bodySize()
    }
    
    func loadPreview(note: Note) {
        let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)
        let markdownString = note.getPrettifiedContent()
        
        do {
            guard var imagesStorage = note.project?.url else { return }
            
            if note.type == .TextBundle {
                imagesStorage = note.url
            }
            
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
            let range = editArea.selectedRange
            let keyboardIsOpen = editArea.isFirstResponder
            print(keyboardIsOpen)
            
            if keyboardIsOpen {
                editArea.endEditing(true)
            }
            
            if NightNight.theme == .night {
                editArea.keyboardAppearance = .dark
            } else {
                editArea.keyboardAppearance = .light
            }
            
            fill(note: note)
            
            editArea.selectedRange = range

            if keyboardIsOpen {
                editArea.becomeFirstResponder()
            }
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

        self.restoreRTFTypingAttributes(note: note)

        if note.isMarkdown() {
            self.applyStrikeTypingAttribute(range: range)
        }

        /*
        // Paste in UITextView
        if note.isMarkdown() && text == UIPasteboard.general.string {
            self.editArea.insertText(text)
            NotesTextProcessor.fullScan(note: note, storage: editArea.textStorage, range: NSRange(0..<editArea.textStorage.length), async: true)
            return false
        }
        
        // Delete backward pressed
        if self.deleteBackwardPressed(text: text) {
            self.editArea.deleteBackward()
            let formatter = TextFormatter(textView: self.editArea, note: note, shouldScanMarkdown: false)
            formatter.deleteKey()
            return false
        }
        */
        
        // New line
        if text == "\n" {
            let formatter = TextFormatter(textView: self.editArea, note: note, shouldScanMarkdown: false)
            formatter.newLine()

            if note.isMarkdown() {
                let processor = NotesTextProcessor(note: note, storage: editArea.textStorage, range: range)
                processor.scanParagraph()
            }

            return false
        }
        
        // Tab
        if text == "\t" {
            let formatter = TextFormatter(textView: self.editArea, note: note, shouldScanMarkdown: false)
            formatter.tabKey()
            return false
        }

        if let font = self.editArea.typingFont {
            editArea.typingAttributes[NSAttributedStringKey.font.rawValue] = font
        }

        return true
    }

    private func applyStrikeTypingAttribute(range: NSRange) {
        let string = editArea.textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: range)
        let paragraph = editArea.textStorage.attributedSubstring(from: paragraphRange)

        if paragraph.length > 0, let attachment = paragraph.attribute(NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.todo"), at: 0, effectiveRange: nil) as? Int, attachment == 1 {
            editArea.typingAttributes[NSAttributedStringKey.strikethroughStyle.rawValue] = 1
        } else {
            editArea.typingAttributes.removeValue(forKey: NSAttributedStringKey.strikethroughStyle.rawValue)
        }
    }

    private func restoreRTFTypingAttributes(note: Note) {
        guard note.isRTF() else { return }

        let formatter = TextFormatter(textView: editArea, note: note)

        self.editArea.typingAttributes[NSAttributedStringKey.font.rawValue] = formatter.getTypingAttributes()
    }

    private func getDefaultFont() -> UIFont {
        var font = UserDefaultsManagement.noteFont!

        if #available(iOS 11.0, *) {
            let fontMetrics = UIFontMetrics(forTextStyle: .body)
            font = fontMetrics.scaledFont(for: font)
        }

        return font
    }

    private func deleteBackwardPressed(text: String) -> Bool {
        if !self.isUndo, let char = text.cString(using: String.Encoding.utf8), strcmp(char, "\\b") == -92 {
            return true
        }
        
        self.isUndo = false
        
        return false
    }
    
    var inProgress = false
    var change = 0
    
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
        let processor = NotesTextProcessor(note: note, storage: storage, range: range)
        
        if note.type == .PlainText || note.type == .RichText {
            processor.higlightLinks()
        } else {
            processor.scanParagraph()
        }
        
        self.storageQueue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock {
            DispatchQueue.main.async {
                note.content = NSMutableAttributedString(attributedString: self.editArea.attributedText)
                note.save()
            }
        }
        self.storageQueue.addOperation(operation)
        
        if var font = UserDefaultsManagement.noteFont {
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font)
            }
            editArea.typingAttributes[NSAttributedStringKey.font.rawValue] = font
        }
        
        editArea.initUndoRedoButons()
        
        vc.cloudDriveManager?.cloudDriveQuery.enableUpdates()
        vc.shouldReloadNotes = true
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
    
    func addToolBar(textField: UITextView, toolbar: UIToolbar) {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: toolbar.frame.height))
        scroll.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentSize = CGSize(width: toolbar.frame.width, height: toolbar.frame.height)
        scroll.addSubview(toolbar)

        textField.delegate = self
        textField.inputAccessoryView = scroll

        if let etv = textField as? EditTextView {
            etv.initUndoRedoButons()
        }
    }

    private func getMarkdownToolbar() -> UIToolbar {
        let toolBar = UIToolbar()
        toolBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        toolBar.barStyle = .blackTranslucent
        toolBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)

        let imageButton = UIBarButtonItem(image: UIImage(named: "image"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.imagePressed))
        let boldButton = UIBarButtonItem(image: #imageLiteral(resourceName: "bold.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.boldPressed))
        let italicButton = UIBarButtonItem(image: #imageLiteral(resourceName: "italic.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.italicPressed))
        let indentButton = UIBarButtonItem(image: #imageLiteral(resourceName: "indent.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.indentPressed))
        let unindentButton = UIBarButtonItem(image: #imageLiteral(resourceName: "unindent.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.unIndentPressed))
        let headerButton = UIBarButtonItem(image: #imageLiteral(resourceName: "header.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.headerPressed))
        let todoButton = UIBarButtonItem(image: UIImage(named: "todo"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.todoPressed))
        let undoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "undo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.undoPressed))
        let redoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "redo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.redoPressed))

        let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(EditorViewController.donePressed))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)

        toolBar.setItems([todoButton, boldButton, italicButton, indentButton, unindentButton, headerButton, imageButton, spaceButton, undoButton, redoButton, doneButton], animated: false)

        toolBar.isUserInteractionEnabled = true
        toolBar.frame = CGRect.init(x: 0, y: 0, width: 420, height: 44)

        return toolBar
    }

    private func getRTFToolbar() -> UIToolbar {
        let toolBar = UIToolbar()
        toolBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)

        toolBar.isTranslucent = true
        toolBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)

        let boldButton = UIBarButtonItem(image: #imageLiteral(resourceName: "bold.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.boldPressed))
        let italicButton = UIBarButtonItem(image: #imageLiteral(resourceName: "italic.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.italicPressed))
        let strikeButton = UIBarButtonItem(image: UIImage(named: "strike.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.strikePressed))
        let underlineButton = UIBarButtonItem(image: UIImage(named: "underline.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.underlinePressed))

        let undoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "undo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.undoPressed))
        let redoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "redo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.redoPressed))

        let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(EditorViewController.donePressed))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)

        toolBar.setItems([boldButton, italicButton, strikeButton, underlineButton, spaceButton, undoButton, redoButton, doneButton], animated: false)

        toolBar.isUserInteractionEnabled = true
        toolBar.sizeToFit()

        return toolBar
    }

    private func getPlainTextToolbar() -> UIToolbar {
        let toolBar = UIToolbar()
        toolBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)

        toolBar.isTranslucent = true
        toolBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)

        let undoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "undo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.undoPressed))
        let redoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "redo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.redoPressed))

        let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(EditorViewController.donePressed))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)

        toolBar.setItems([spaceButton, undoButton, redoButton, doneButton], animated: false)

        toolBar.isUserInteractionEnabled = true
        toolBar.sizeToFit()

        return toolBar
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

    @objc func strikePressed(){
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.strike()
        }
    }

    @objc func underlinePressed(){
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.underline()
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
    
    @objc func todoPressed() {
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.toggleTodo()
            
            AudioServicesPlaySystemSound(1519)
        }
    }

    @objc func imagePressed() {
        if let note = self.note {
            let pickerController = DKImagePickerController()
            pickerController.assetType = .allPhotos

            pickerController.didSelectAssets = { (assets: [DKAsset]) in
                var processed = 0
                var markup = ""

                for asset in assets {
                    asset.fetchOriginalImage(true, completeBlock: { image, info in
                        processed += 1

                        guard var url = info?["PHImageFileURLKey"] as? URL else { return }
                        let data: Data?
                        let isHeic = url.pathExtension.lowercased() == "heic"

                        if isHeic, let imageUnwrapped = image {
                            data = UIImageJPEGRepresentation(imageUnwrapped, 0.7);
                            url.deletePathExtension()
                            url.appendPathExtension("jpg")
                        } else {
                            do {
                                data = try Data(contentsOf: url)
                            } catch {
                                return
                            }
                        }

                        guard let imageData = data else { return }

                        let processor = ImagesProcessor(styleApplier: self.editArea.textStorage, note: note)
                        guard let fileName = processor.writeImage(data: imageData, url: url) else { return }

                        if note.type == .TextBundle {
                            markup += "![](assets/\(fileName))"
                        } else {
                            markup += "![](/i/\(fileName))"
                        }

                        markup += "\n\n"

                        guard processed == assets.count else { return }

                        DispatchQueue.main.async {
                            self.editArea.insertText(markup)

                            note.content = NSMutableAttributedString(attributedString: self.editArea.attributedText)
                            note.save()

                            self.editArea.undoManager?.removeAllActions()
                            self.refill()
                        }
                    })
                }
            }

            present(pickerController, animated: true) {}
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
        
        self.isUndo = true
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
        guard let note = self.note else { return }

        var linkAttributes: [String : Any] = [
            NSAttributedStringKey.foregroundColor.rawValue: NightNight.theme == .night ? UIColor(red:0.49, green:0.92, blue:0.63, alpha:1.0) : UIColor(red:0.24, green:0.51, blue:0.89, alpha:1.0)
        ]

        if !note.isRTF() {
            linkAttributes[NSAttributedStringKey.underlineColor.rawValue] = UIColor.lightGray
            linkAttributes[NSAttributedStringKey.underlineStyle.rawValue] = NSUnderlineStyle.styleNone.rawValue
        }
        
        if editArea != nil {
            editArea.linkTextAttributes = linkAttributes
        }
    }
    
    @objc private func tapHandler(_ sender: UITapGestureRecognizer) {
        let myTextView = sender.view as! UITextView
        let layoutManager = myTextView.layoutManager
        
        var location = sender.location(in: myTextView)
        location.x -= myTextView.textContainerInset.left;
        location.y -= myTextView.textContainerInset.top;
        
        var characterIndex = layoutManager.characterIndex(for: location, in: myTextView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        // Image preview on click
        if self.editArea.isImage(at: characterIndex) {
            let todoKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.path")

            guard let path = myTextView.textStorage.attribute(todoKey, at: characterIndex, effectiveRange: nil) as? String, let note = self.note, let url = note.getImageUrl(imageName: path) else { return }

            if let someImage = UIImage(contentsOfFile: url.path) {

                let imageInfo   = GSImageInfo(image: someImage, imageMode: .aspectFit)
                let transitiionInfo = GSTransitionInfo(fromRect: CGRect.init())
                let imageViewer = GSImageViewerController(imageInfo: imageInfo, transitionInfo: transitiionInfo)
                present(imageViewer, animated: true, completion: nil)
            }

            return
        }

        let char = Array(myTextView.textStorage.string)[characterIndex]

        // Toggle todo on click
        if characterIndex + 1 < myTextView.textStorage.length, char != "\n", self.isTodo(location: characterIndex, textView: myTextView), let note = self.note {
            let textFormatter = TextFormatter(textView: self.editArea!, note: note)
            let range = myTextView.selectedRange
            textFormatter.toggleTodo(characterIndex)
            textFormatter.setSelectedRange(range)
            
            AudioServicesPlaySystemSound(1519)
            return
        }
        
        DispatchQueue.main.async {
            self.editArea.becomeFirstResponder()
            
            if myTextView.textStorage.length > 0 && characterIndex == myTextView.textStorage.length - 1 {
                characterIndex += 1
            }
            
            self.editArea.selectedRange = NSMakeRange(characterIndex, 0)
        }
    }
    
    private func isTodo(location: Int, textView: UITextView) -> Bool {
        let storage = textView.textStorage
        
        let todoKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.todo")
        if storage.attribute(todoKey, at: location, effectiveRange: nil) != nil {
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

}
