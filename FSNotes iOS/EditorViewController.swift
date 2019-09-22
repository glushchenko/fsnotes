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

class EditorViewController: UIViewController, UITextViewDelegate {
    public var note: Note?
    
    private var isHighlighted: Bool = false
    private var isUndo = false
    private let storageQueue = OperationQueue()
    private var toolbar: Toolbar = .markdown

    var inProgress = false
    var change = 0

    private var initialKeyboardHeight: CGFloat = 0

    @IBOutlet weak var editArea: EditTextView!

    var rowUpdaterTimer = Timer()
    
    override func viewDidLoad() {
        storageQueue.maxConcurrentOperationCount = 1
        
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = Colors.buttonText
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        navigationController?.navigationBar.mixedBackgroundColor = Colors.Header

        self.navigationItem.rightBarButtonItem = self.getShareButton()
        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        let imageTap = SingleImageTouchDownGestureRecognizer(target: self, action: #selector(imageTapHandler(_:)))
        self.editArea.addGestureRecognizer(imageTap)

        let tap = SingleTouchDownGestureRecognizer(target: self, action: #selector(tapHandler(_:)))
        self.editArea.addGestureRecognizer(tap)

        self.editArea.textStorage.delegate = self.editArea.textStorage

        EditTextView.imagesLoaderQueue.maxConcurrentOperationCount = 1
        EditTextView.imagesLoaderQueue.qualityOfService = .userInteractive

        super.viewDidLoad()

        self.addToolBar(textField: editArea, toolbar: self.getMarkdownToolbar())

        guard let pageController = self.parent as? PageViewController else {
            return
        }
        
        pageController.enableSwipe()
        
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: UIContentSizeCategory.didChangeNotification, object: nil)

        editArea.keyboardDismissMode = .interactive
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { (ctx) in
            self.refillToolbar()
            self.refill()
        })
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

        if NightNight.theme == .night {
            editArea.keyboardAppearance = .dark
        } else {
            editArea.keyboardAppearance = .default
        }

        initLinksColor()

        editArea.indicatorStyle = (NightNight.theme == .night) ? .white : .black
        editArea.flashScrollIndicators()
    }

    override func viewWillAppear(_ animated: Bool) {
        self.registerForKeyboardNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.deregisterFromKeyboardNotifications()
    }

    override var textInputMode: UITextInputMode? {
        let defaultLang = UserDefaultsManagement.defaultLanguage
        
        if UITextInputMode.activeInputModes.count - 1 >= defaultLang {
            return UITextInputMode.activeInputModes[defaultLang]
        }
        
        return super.textInputMode
    }

    private func registerForKeyboardNotifications(){
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func deregisterFromKeyboardNotifications(){
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    public func getToolbar(for note: Note) -> UIToolbar {
        if note.isMarkdown() {
            return self.getMarkdownToolbar()
        }

        if note.type == .RichText {
            return self.getRTFToolbar()
        }

        return self.getPlainTextToolbar()
    }

    public func refillToolbar() {
        guard let note = self.note else { return }

        self.addToolBar(textField: self.editArea, toolbar: self.getToolbar(for: note))
    }

    public func setTitle(text: String) {
        let button =  UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
        button.setTitle(text, for: .normal)
        button.addTarget(self, action: #selector(self.clickOnButton), for: .touchUpInside)
        self.navigationItem.titleView = button
        self.navigationItem.title = text
    }

    public func fill(note: Note, preview: Bool = false) {

        self.note = note
        EditTextView.note = note
        
        UserDefaultsManagement.codeTheme = NightNight.theme == .night ? "monokai-sublime" : "atom-one-light"

        setTitle(text: note.getShortTitle())
        _ = view

        guard editArea != nil else { return }

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

            if let font = UserDefaultsManagement.noteFont {
                editArea.attributedText = NSAttributedString(string: note.content.string, attributes: [
                        .foregroundColor: foregroundColor,
                        .font: font
                    ]
                )
            }
        } else {
            EditTextView.shouldForceRescan = true

            if UserDefaultsManagement.liveImagesPreview {
                if let content = note.content.mutableCopy() as? NSMutableAttributedString {
                    let processor = ImagesProcessor(styleApplier: content, range: NSRange(0..<content.length), note: note)
                    processor.load()

                    editArea.attributedText = content
                }
            } else {
                editArea.attributedText = note.content
            }
        }

        self.configureToolbar()

        editArea.textStorage.updateFont()

        if note.isMarkdown() {
            note.isCached = false
            EditTextView.isBusyProcessing = true
            editArea.textStorage.replaceCheckboxes()
            EditTextView.isBusyProcessing = false
        }
        
        editArea.delegate = self

        let cursor = editArea.selectedTextRange
        let storage = editArea.textStorage

        let search = getSearchText()
        if search.count > 0 {
            let processor = NotesTextProcessor(storage: storage)
            processor.highlightKeyword(search: search)
            isHighlighted = true
        }
        
        editArea.selectedTextRange = cursor

        if note.type != .RichText {
            editArea.typingAttributes[.font] = UIFont.bodySize()
        } else {
            editArea.typingAttributes[.foregroundColor] =
                UIColor.black
        }

        editArea.applyLeftParagraphStyle()
    }

    @objc private func clickOnButton() {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageController.orderedViewControllers[0] as? ViewController else {
                return
        }

        guard let note = self.note else { return }

        vc.notesTable.actionsSheet(notes: [note], showAll: true, presentController: self)
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

        if let scroll = editArea.inputAccessoryView as? UIScrollView {
            scroll.contentOffset = .zero
        }
    }
    
    func refill() {
        initLinksColor()
        
        if let note = self.note {
            let range = editArea.selectedRange
            let keyboardIsOpen = editArea.isFirstResponder
            
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
    
    // RTF style completions
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {

        guard let note = self.note else {
            return true
        }

        if text == "" {
            let lastChar = textView.textStorage.attributedSubstring(from: range).string
            if lastChar.count == 1 {
                EditTextView.lastRemoved = lastChar
            }
        }

        self.restoreRTFTypingAttributes(note: note)

        if note.isMarkdown() {
            deleteUnusedImages(checkRange: range)

            self.applyStrikeTypingAttribute(range: range)
        }

        // New line
        if text == "\n" {
            let formatter = TextFormatter(textView: self.editArea, note: note, shouldScanMarkdown: false)
            formatter.newLine()
            return false
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            editArea.typingAttributes[.paragraphStyle] = paragraphStyle
        }

        // Tab
        if text == "\t" {
            let formatter = TextFormatter(textView: self.editArea, note: note, shouldScanMarkdown: false)
            formatter.tabKey()
            return false
        }

        if let font = self.editArea.typingFont {
            editArea.typingAttributes[.font] = font
        }

        return true
    }

    private func deleteUnusedImages(checkRange: NSRange) {
        let storage = editArea.textStorage
        var removedImages = [URL: URL]()

        storage.enumerateAttribute(.attachment, in: checkRange) { (value, range, _) in
            if let _ = value as? NSTextAttachment, storage.attribute(.todo, at: range.location, effectiveRange: nil) == nil {

                let filePathKey = NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.path")

                if let filePath = storage.attribute(filePathKey, at: range.location, effectiveRange: nil) as? String {

                    if let note = EditTextView.note {
                        guard let imageURL = note.getImageUrl(imageName: filePath) else { return }

                        let trashURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(imageURL.lastPathComponent)

                        do {
                            try FileManager.default.moveItem(at: imageURL, to: trashURL)

                            removedImages[trashURL] = imageURL
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        }

        if removedImages.count > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.editArea.undoManager?.registerUndo(withTarget: self, handler: { (targetSelf) in
                    targetSelf.unDeleteImages(removedImages)
                })

                self.editArea.undoManager?.setActionName("Delete image")
            }
        }
    }

    @objc public func unDeleteImages(_ urls: [URL: URL]) {
        for (src, dst) in urls {
            do {
                try FileManager.default.moveItem(at: src, to: dst)
            } catch {
                print(error)
            }
        }
    }

    private func applyStrikeTypingAttribute(range: NSRange) {
        let string = editArea.textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: range)
        let paragraph = editArea.textStorage.attributedSubstring(from: paragraphRange)

        if paragraph.length > 0, let attachment = paragraph.attribute(NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.todo"), at: 0, effectiveRange: nil) as? Int, attachment == 1 {
            editArea.typingAttributes[.strikethroughStyle] = 1
        } else {
            editArea.typingAttributes.removeValue(forKey: .strikethroughStyle)
        }
    }

    private func restoreRTFTypingAttributes(note: Note) {
        guard note.isRTF() else { return }

        let formatter = TextFormatter(textView: editArea, note: note)

        self.editArea.typingAttributes[.font] = formatter.getTypingAttributes()
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

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard let note = self.note else { return }

        if textView.isFirstResponder {
            note.setLastSelectedRange(value: textView.selectedRange)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageController.orderedViewControllers[0] as? ViewController else {
                return
        }
        
        vc.cloudDriveManager?.metadataQuery.disableUpdates()
        
        guard let note = self.note else { return }
        
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
        }
        
        self.storageQueue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self] in
            guard let self = self else {return}
            
            DispatchQueue.main.async {
                note.content = NSMutableAttributedString(attributedString: self.editArea.attributedText)
                note.save()

                self.rowUpdaterTimer.invalidate()
                self.rowUpdaterTimer = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(self.updateCurrentRow), userInfo: nil, repeats: false)
            }
        }
        self.storageQueue.addOperation(operation)
        
        if var font = UserDefaultsManagement.noteFont {
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font)
            }

            editArea.typingAttributes.removeValue(forKey: .backgroundColor)
            editArea.typingAttributes[.font] = font
        }
        
        editArea.initUndoRedoButons()
        
        vc.cloudDriveManager?.metadataQuery.enableUpdates()
        vc.notesTable.moveRowUp(note: note)
    }

    @objc private func updateCurrentRow() {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageController.orderedViewControllers[0] as? ViewController,
            let note = self.note
        else {
            return
        }

        note.invalidateCache()
        vc.notesTable.beginUpdates()
        vc.notesTable.reloadRow(note: note)
        vc.notesTable.endUpdates()
    }
    
    func getSearchText() -> String {
        if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[0] as? ViewController, let search = viewController.search.text {
            return search
        }
        return ""
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        guard var keyboardFrame: CGRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }

        keyboardFrame = view.convert(keyboardFrame, from: nil)
        let keyboardHeight = keyboardFrame.height

        if initialKeyboardHeight == 0 {
            initialKeyboardHeight = keyboardHeight + 44
        }

        var padding: CGFloat = 0
        if keyboardHeight < initialKeyboardHeight - 44 {
            padding = 44
        }

        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardHeight + padding, right: 0.0)
        self.editArea.contentInset = contentInsets
        self.editArea.scrollIndicatorInsets = contentInsets

        guard let note = self.note else { return }
        note.setLastSelectedRange(value: editArea.selectedRange)
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        initialKeyboardHeight = 0
        let contentInsets = UIEdgeInsets.zero
        editArea.contentInset = contentInsets
        editArea.scrollIndicatorInsets = contentInsets
    }

    func addToolBar(textField: UITextView, toolbar: UIToolbar) {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: toolbar.frame.height))
        scroll.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x272829)
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentSize = CGSize(width: toolbar.frame.width, height: toolbar.frame.height)
        scroll.addSubview(toolbar)

        let topBorder = CALayer()
        topBorder.frame = CGRect(x: -1000, y: 0, width: 9999, height: 1)
        topBorder.mixedBackgroundColor = MixedColor(normal: 0x989898, night: 0x000000)
        scroll.layer.addSublayer(topBorder)

        let isFirst = textField.isFirstResponder
        if isFirst {
            textField.endEditing(true)
        }

        textField.inputAccessoryView = scroll

        if isFirst {
            textField.becomeFirstResponder()
        }

        if let etv = textField as? EditTextView {
            etv.initUndoRedoButons()
        }
    }

    private func getMarkdownToolbar() -> UIToolbar {
        let imageButton = UIBarButtonItem(image: UIImage(named: "image"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.imagePressed))
        let boldButton = UIBarButtonItem(image: #imageLiteral(resourceName: "bold.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.boldPressed))

        let italicButton = UIBarButtonItem(image: #imageLiteral(resourceName: "italic.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.italicPressed))
        italicButton.tag = 0x03

        let indentButton = UIBarButtonItem(image: #imageLiteral(resourceName: "indent.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.indentPressed))
        let unindentButton = UIBarButtonItem(image: #imageLiteral(resourceName: "unindent.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.unIndentPressed))
        let headerButton = UIBarButtonItem(image: #imageLiteral(resourceName: "header.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.headerPressed))

        let codeBlockImage = UIImage(named: "codeBlockAsset")?.resize(maxWidthHeight: 30)
        let codeblockButton = UIBarButtonItem(image: codeBlockImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.codeBlockButton))
        let todoButton = UIBarButtonItem(image: UIImage(named: "todo"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.todoPressed))

        let quoteImage = UIImage(named: "quote")?.resize(maxWidthHeight: 25)
        let quoteButton = UIBarButtonItem(image: quoteImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.quotePressed))

        let undoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "undo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.undoPressed))
        let redoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "redo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.redoPressed))

        let items = [todoButton, boldButton, italicButton, headerButton, imageButton, codeblockButton, quoteButton, indentButton, unindentButton, undoButton, redoButton]

        var width = CGFloat(0)
        for item in items {
            if item.tag == 0x03 {
                item.width = 30
                width += 30
            } else {
                item.width = 50
                width += 50
            }
        }

        let toolBar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: width, height: 44))
        toolBar.isTranslucent = false
        toolBar.mixedBarTintColor = MixedColor(normal: 0xffffff, night: 0x272829)
        toolBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        toolBar.setItems(items, animated: false)
        toolBar.isUserInteractionEnabled = true

        return toolBar
    }

    private func getRTFToolbar() -> UIToolbar {
        let width = self.editArea.superview!.frame.width
        let toolBar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: width, height: 44))

        toolBar.mixedBarTintColor = MixedColor(normal: 0xe9e9e9, night: 0x47444e)
        toolBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)

        let boldButton = UIBarButtonItem(image: #imageLiteral(resourceName: "bold.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.boldPressed))
        let italicButton = UIBarButtonItem(image: #imageLiteral(resourceName: "italic.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.italicPressed))
        let strikeButton = UIBarButtonItem(image: UIImage(named: "strike.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.strikePressed))
        let underlineButton = UIBarButtonItem(image: UIImage(named: "underline.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.underlinePressed))

        let undoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "undo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.undoPressed))
        let redoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "redo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.redoPressed))

        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)

        toolBar.setItems([boldButton, italicButton, strikeButton, underlineButton, spaceButton, undoButton, redoButton], animated: false)

        toolBar.isUserInteractionEnabled = true
        toolBar.sizeToFit()

        return toolBar
    }

    private func getPlainTextToolbar() -> UIToolbar {
        let width = self.editArea.superview!.frame.width
        let toolBar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: width, height: 44))

        toolBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        toolBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)

        let undoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "undo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.undoPressed))
        let redoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "redo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.redoPressed))

        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)

        toolBar.setItems([spaceButton, undoButton, redoButton], animated: false)

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

    @objc func codeBlockButton() {
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note, shouldScanMarkdown: false)
            formatter.codeBlock()
        }
    }

    @objc func quotePressed() {
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note, shouldScanMarkdown: false)
            formatter.quote()

            AudioServicesPlaySystemSound(1519)
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
                    let options = PHImageRequestOptions.init()
                    options.deliveryMode = .highQualityFormat

                    asset.fetchOriginalImage(options: nil, completeBlock: { image, info in
                        processed += 1

                        var imageExt = "jpg"
                        if let uti = info?["PHImageFileUTIKey"] as? String, let ext = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() {
                            imageExt = String(ext)
                        }

                        var url = URL(fileURLWithPath: "file:///tmp/" + UUID().uuidString + "." + imageExt)
                        let data: Data?

                        if let fileURL = info?["PHImageFileURLKey"] as? URL,
                            fileURL.pathExtension.lowercased() == "heic",
                            let imageUnwrapped = image
                        {
                            data = imageUnwrapped.jpegData(compressionQuality: 1);
                            url.deletePathExtension()
                            url.appendPathExtension("jpg")
                        } else if let fileData = info?["PHImageFileDataKey"] as? Data {
                            if imageExt == "heic" {
                                data = UIImage(data: fileData)?.jpegData(compressionQuality: 1)
                                imageExt = "jpg"
                            } else {
                                data = fileData
                            }
                        } else {
                            do {
                                data = try Data(contentsOf: url)
                            } catch {
                                return
                            }
                        }

                        guard let imageData = data else { return }

                        if UserDefaultsManagement.liveImagesPreview {
                            self.editArea.saveImageClipboard(data: imageData, note: note, ext: imageExt)



                            if processed == assets.count {
                                note.save()
                                return
                            }

                            if assets.count != 1 {
                                self.editArea.insertText("\n\n")
                            }

                            return
                        }

                        guard let fileName = ImagesProcessor.writeImage(data: imageData, url: url, note: note, ext: imageExt) else { return }

                        if note.isTextBundle() {
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
                            note.isParsed = false

                            self.editArea.undoManager?.removeAllActions()
                            self.refill()
                        }
                    })
                }
            }

            present(pickerController, animated: true) {}
        }
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

        if um.undoActionName == "Delete image" {
            um.undo()
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

    func initLinksColor() {
        guard let note = self.note else { return }

        var linkAttributes: [NSAttributedString.Key : Any] = [
            .foregroundColor: NightNight.theme == .night ? UIColor(red:0.49, green:0.92, blue:0.63, alpha:1.0) : UIColor(red:0.24, green:0.51, blue:0.89, alpha:1.0)
        ]

        if !note.isRTF() {
            linkAttributes[.underlineColor] = UIColor.lightGray
            linkAttributes[.underlineStyle] = 0
        }
        
        if editArea != nil {
            editArea.linkTextAttributes = linkAttributes
        }
    }

    @objc private func tapHandler(_ sender: SingleTouchDownGestureRecognizer) {
        let myTextView = sender.view as! UITextView
        guard let characterIndex = sender.touchCharIndex else { return}
        let char = myTextView.textStorage.mutableString.substring(with: NSRange(location: characterIndex, length: 1))

        // Toggle todo on click
        if characterIndex + 1 < myTextView.textStorage.length, char != "\n", self.isTodo(location: characterIndex, textView: myTextView), let note = self.note {
            self.editArea.isAllowedScrollRect = false
            let textFormatter = TextFormatter(textView: self.editArea!, note: note)
            textFormatter.toggleTodo(characterIndex)

            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
                self.editArea.isAllowedScrollRect = true
            }

            AudioServicesPlaySystemSound(1519)
            return
        }

        // Image preview/selection on click
        if self.editArea.isImage(at: characterIndex) && myTextView.textStorage.attribute(.todo, at: characterIndex, effectiveRange: nil) == nil {

            // Select and show menu
            guard !self.editArea.isFirstResponder else {
                self.editArea.selectedRange = NSRange(location: characterIndex, length: 1)

                guard let lasTouchPoint = self.editArea.lasTouchPoint else { return }
                let rect = CGRect(x: self.editArea.frame.width / 2, y: lasTouchPoint.y, width: 0, height: 0)

                UIMenuController.shared.setTargetRect(rect, in: self.view)
                UIMenuController.shared.setMenuVisible(true, animated: true)
                return
            }

            let pathKey = NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.path")

            guard let path = myTextView.textStorage.attribute(pathKey, at: characterIndex, effectiveRange: nil) as? String, let note = self.note, let url = note.getImageUrl(imageName: path) else { return }

            if let data = try? Data(contentsOf: url), let someImage = UIImage(data: data) {
                let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
                let imagePreviewViewController = storyBoard.instantiateViewController(withIdentifier: "imagePreviewViewController") as! ImagePreviewViewController

                imagePreviewViewController.image = someImage
                imagePreviewViewController.url = url
                present(imagePreviewViewController, animated: true, completion: nil)
            }

            return
        }

        // Links
        if self.editArea.isLink(at: characterIndex) {
            if self.editArea.isFirstResponder {
                DispatchQueue.main.async {
                    self.editArea.selectedRange = NSRange(location: characterIndex, length: 0)
                }
                return
            }

            guard let path = self.editArea.textStorage.attribute(.link, at: characterIndex, effectiveRange: nil) as? String else { return }

            if path.starts(with: "fsnotes://find/") {
                let fileName = path.replacingOccurrences(of: "fsnotes://find/", with: "")
                if let note = Storage.instance?.getBy(title: fileName) {
                    fill(note: note)
                }
            } else if let url = URL(string: path) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return
        }
    }

    @objc private func imageTapHandler(_ sender: SingleImageTouchDownGestureRecognizer) {
        guard let view = sender.view as? UITextView else { return }

        let layoutManager = view.layoutManager
        let location = sender.location(in: view)

        var characterIndex = layoutManager.characterIndex(for: location, in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        DispatchQueue.main.async {
            view.becomeFirstResponder()

            if sender.isRightBorderTap {
                characterIndex += 1
            }

            view.selectedRange = NSRange(location: characterIndex, length: 0)
        }
    }

    private func isTodo(location: Int, textView: UITextView) -> Bool {
        let storage = textView.textStorage

        if storage.attribute(.todo, at: location, effectiveRange: nil) != nil {
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

    private func getShareButton() -> UIBarButtonItem {
        let menuBtn = UIButton(type: .custom)
        menuBtn.frame = CGRect(x: 0.0, y: 0.0, width: 20, height: 20)
        menuBtn.setImage(UIImage(named: "share"), for: .normal)
        menuBtn.addTarget(self, action: #selector(share), for: UIControl.Event.touchUpInside)

        let menuBarItem = UIBarButtonItem(customView: menuBtn)
        let currWidth = menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 24)
        currWidth?.isActive = true
        let currHeight = menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 24)
        currHeight?.isActive = true

        menuBarItem.tintColor = UIColor.white
        return menuBarItem
    }

    @objc public func cancel() {
        if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController {
            pageController.switchToList()
        }
    }

    @objc public func share() {
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let mvc = pageController.mainViewController,
            let evc = pageController.editorViewController,
            let note = evc.note
        else { return }

        mvc.notesTable.shareAction(note: note, presentController: evc)
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {

        if textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.selectedRange = NSRange(location: characterRange.upperBound, length: 0)
            }
            return false
        }

        // Skip images (fixes glitch bug)
        let pathKey = NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.path")
        let attr = textView.textStorage.attribute(pathKey, at: characterRange.location, effectiveRange: nil)
        
        if attr != nil && !textView.isFirstResponder {
            return false
        }

        return true
    }

    func textView(_ textView: UITextView, shouldInteractWith textAttachment: NSTextAttachment, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return false
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        if let recognizers = editArea.gestureRecognizers {
            for recognizer in recognizers {
                if recognizer.isKind(of: UIGestureRecognizer.self) {
                    if #available(iOS 11.0, *) {
                        if [
                            "com.apple.UIKit.longPressClickDriverPrimary",
                            "com.apple.UIKit.clickPresentationExclusion",
                            "com.apple.UIKit.clickPresentationFailure",
                            "dragFailureRelationships",
                            "dragExclusionRelationships",
                            "dragInitiation"
                            ].contains(recognizer.name) {
                            recognizer.isEnabled = true
                        }
                    }
                }
            }
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        initialKeyboardHeight = 0

        if let recognizers = editArea.gestureRecognizers {
            for recognizer in recognizers {
                if recognizer.isKind(of: UIGestureRecognizer.self) {
                    if #available(iOS 11.0, *) {
                        if ["com.apple.UIKit.longPressClickDriverPrimary", "com.apple.UIKit.clickPresentationExclusion", "com.apple.UIKit.clickPresentationFailure", "dragFailureRelationships", "dragExclusionRelationships", "dragInitiation"].contains(recognizer.name) {
                            recognizer.isEnabled = false
                        }
                    }
                }
            }
        }
    }
}
