//
//  EditorViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/31/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight
import AudioToolbox
import DKImagePickerController
import MobileCoreServices
import Photos
import DropDown
import CoreSpotlight

class EditorViewController: UIViewController, UITextViewDelegate, UIDocumentPickerDelegate {
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

    public var tagsTimer: Timer?
    private let dropDown = DropDown()
    public var isUndoAction: Bool = false

    private var isLandscape: Bool?

    // used for non icloud changes detection
    private var coreNote: CoreNote?

    override func viewDidLoad() {
        storageQueue.maxConcurrentOperationCount = 1
        
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = Colors.buttonText
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        navigationController?.navigationBar.mixedBackgroundColor = Colors.Header

        self.navigationItem.rightBarButtonItems = [getMoreButton(), self.getPreviewButton()]
        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        let imageTap = SingleImageTouchDownGestureRecognizer(target: self, action: #selector(imageTapHandler(_:)))
        editArea.addGestureRecognizer(imageTap)

        let tap = SingleTouchDownGestureRecognizer(target: self, action: #selector(tapHandler(_:)))
        editArea.addGestureRecognizer(tap)
        editArea.textStorage.delegate = editArea.textStorage

        EditTextView.imagesLoaderQueue.maxConcurrentOperationCount = 1
        EditTextView.imagesLoaderQueue.qualityOfService = .userInteractive

        super.viewDidLoad()

        self.addToolBar(textField: editArea, toolbar: self.getMarkdownToolbar())

        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: UIContentSizeCategory.didChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(refill), name: NSNotification.Name(rawValue: "es.fsnot.external.file.changed"), object: nil)

        editArea.keyboardDismissMode = .interactive
    }

    @objc func rotated() {
        guard isLandscape != nil else {
            isLandscape = UIDevice.current.orientation.isLandscape
            navigationController?.isNavigationBarHidden = isLandscape!
            return
        }

        let isLand = UIDevice.current.orientation.isLandscape
        if let landscape = self.isLandscape, landscape != isLand, !UIDevice.current.orientation.isFlat {
            isLandscape = isLand
            navigationController?.isNavigationBarHidden = isLand
        } else {
            navigationController?.isNavigationBarHidden = false
        }
    }

//    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        super.viewWillTransition(to: size, with: coordinator)
//
//        coordinator.animate(alongsideTransition: { (ctx) in
//            self.refillToolbar()
//            self.refill()
//        })
//    }

    override func viewDidAppear(_ animated: Bool) {
        editArea.isScrollEnabled = true
        
        if let n = note, n.isMarkdown() {
            self.navigationItem.rightBarButtonItem?.title = NSLocalizedString("Preview", comment: "")
        }
        
        super.viewDidAppear(animated)

        if editArea.textStorage.length == 0 {
            editArea.perform(#selector(becomeFirstResponder), with: nil, afterDelay: 0)
        }

        if let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController {
            bvc.enableSwipe()
        }

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
        if note.type == .RichText {
            return self.getRTFToolbar()
        }

        return self.getMarkdownToolbar()
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

        UIApplication.getPVC()?.setTitle(text: text)
    }

    public func fill(note: Note, clearPreview: Bool = false, enableHandoff: Bool = true, completion: (() -> ())? = nil) {

        if enableHandoff {
            registerHandoff(for: note)
        }

        self.note = note
        if !note.isLoaded || note.project.isExternal {
            note.load()
        }

        // for projects added from another app spaces
        // changes detector
        
//        if note.project.isExternal {
//            if coreNote != nil {
//                coreNote?.close()
//            }
//
//            coreNote = CoreNote(note: note)
//            coreNote?.open()
//        } else {
//            coreNote?.close()
//            coreNote = nil
//        }

        EditTextView.note = note

        UserDefaultsManagement.codeTheme = NightNight.theme == .night ? "monokai-sublime" : "atom-one-light"

        setTitle(text: note.getShortTitle())

        if UserDefaultsManagement.previewMode {
            self.fillPreview(note: note)

            completion?()
            return
        }
        
        fillEditor(note: note)
        completion?()

        // prefill preview for parallax effect
        if clearPreview {
            guard let pvc = UIApplication.getPVC() else { return }
            pvc.clear()
        }
    }

    private func fillEditor(note: Note) {
        guard editArea != nil else { return }

        editArea.initUndoRedoButons()

        if note.isRTF() {
            view.backgroundColor = UIColor.white
            editArea.backgroundColor = UIColor.white
        } else {
            view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)
            editArea.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)
        }

        if note.isMarkdown() {
            EditTextView.shouldForceRescan = true

            if let content = note.content.mutableCopy() as? NSMutableAttributedString {
                content.replaceCheckboxes()

                if UserDefaultsManagement.liveImagesPreview {
                    content.loadImages(note: note)
                }

                editArea.attributedText = content
            }
        } else {
            editArea.attributedText = note.content
        }


        self.configureToolbar()

        editArea.textStorage.updateFont()
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

    private func fillPreview(note: Note) {
        guard let pvc = UIApplication.getPVC() else { return }

        pvc.loadPreview(force: true)
    }

    @objc public func clickOnButton() {
        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = pc.containerController.viewControllers[0] as? ViewController,
            let note = self.note
        else { return }

        vc.notesTable.actionsSheet(notes: [note], showAll: true, presentController: self)
    }

    private func configureToolbar() {
        guard let note = self.note else { return }

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
    
    @objc func refill() {
        guard let editArea = editArea else { return }

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

        if isUndoAction {
            isUndoAction = false
            return true
        }

        guard let note = self.note else { return true }

        tagsHandler(affectedCharRange: range, text: text)
        wikilinkHandler(textView: textView, text: text)

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
            paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
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

    private func tagsHandler(affectedCharRange: NSRange, text: String) {
        guard UserDefaultsManagement.inlineTags else { return }

        let textStorage = editArea.textStorage

        if text.count == 1, !["", " ", "\t", "\n"].contains(text) {
            let parRange = textStorage.mutableString.paragraphRange(for: NSRange(location: affectedCharRange.location, length: 0))

            var nextChar = " "
            let nextCharLocation = affectedCharRange.location + 1
            if editArea.selectedRange.length == 0, nextCharLocation <= textStorage.length {
                let nextCharRange = NSRange(location: affectedCharRange.location, length: 1)
                nextChar = textStorage.mutableString.substring(with: nextCharRange)
            }

            if affectedCharRange.location - 1 >= 0 {
                let hashRange = NSRange(location: affectedCharRange.location - 1, length: 1)

                if (textStorage.string as NSString).substring(with: hashRange) == "#" && text != "#" && nextChar.isWhitespace {

                    let vc = UIApplication.getVC()

                    if let project = vc.searchQuery.project {
                        let tags = vc.sidebarTableView.getAllTags(projects: [project])
                        self.dropDown.dataSource = tags.filter({ $0.starts(with: text) })

                        self.complete(offset: hashRange.location, text: text)
                    }
                }
            }

            textStorage.mutableString.enumerateSubstrings(in: parRange, options: .byWords, using: { word, range, _, stop in
                if word == nil || affectedCharRange.location > range.upperBound || affectedCharRange.location < range.lowerBound || range.location <= 0 {
                    return
                }

                let hashRange = NSRange(location: range.location - 1, length: 1)

                if (textStorage.string as NSString).substring(with: hashRange) == "#", nextChar.isWhitespace {

                    let vc = UIApplication.getVC()
                    if let project = vc.searchQuery.project {
                        let tags = vc.sidebarTableView.getAllTags(projects: [project])

                        if let word = word {
                            self.dropDown.dataSource = tags.filter({ $0.starts(with: word + text) })
                        }

                        self.complete(offset: hashRange.location, range: range, text: text)
                        stop.pointee = true
                    }

                    return
                }
            })

            if text == "#" {
                let vc = UIApplication.getVC()

                if let project = vc.searchQuery.project {
                    let tags = vc.sidebarTableView.getAllTags(projects: [project])
                    self.dropDown.dataSource = tags
                    self.complete(offset: self.editArea.selectedRange.location)
                }
            }
        }

        if ["", " ", "\t", "\n"].contains(text), !dropDown.isHidden {
            dropDown.hide()
        }
    }

    private func wikilinkHandler(textView: UITextView, text: String) {
        guard text.count == 1, !["\n"].contains(text) else { return }

        let textStorage = textView.textStorage
        let location = textView.selectedRange.location

        // Encoded offset for Emoji
        guard let cursor = textView.cursorDistance else { return }

        let parRange = textStorage.mutableString.paragraphRange(for: NSRange(location: location, length: 0))

        let paragraph = textStorage.attributedSubstring(from: parRange).string
        guard paragraph.contains("[[") && paragraph.contains("]]"),
            let result = isBetweenBraces(location: cursor) else { return }

        let word = result.0 + text

        guard let titles = Storage.shared().getTitles(by: word) else {
            dropDown.hide()
            return
        }

        dropDown.dataSource = titles

        let range = result.1

        // Decode multibyte offset for Emoji like "🇺🇦"
        let startIndex = textView.text.index(textView.text.startIndex, offsetBy: range.lowerBound + 2)
        let startRange = NSRange(startIndex...startIndex, in: textView.text)
        let replacementRange = NSRange(location: startRange.lowerBound, length: word.count)

        complete(offset: replacementRange.location, replacementRange: replacementRange)
    }

    private func isBetweenBraces(location: Int) -> (String, NSRange)? {
        let storage = editArea.textStorage
        let string = Array(storage.string)
        let length = storage.length

        var firstLeftFound = false
        var firstRigthFound = false

        var rigthFound = false
        var leftFound = false

        var i = location - 1
        var j = location

        while i >= 0 {
            let char = string[i]
            if firstLeftFound {
                leftFound = char == "["
                break
            }

            if char.isNewline {
                break
            }

            if char == "[" {
                firstLeftFound = true
            }

            i -= 1
        }

        while length > j {
            let char = string[j]
            if firstRigthFound {
                rigthFound = char == "]"
                break
            }

            if char.isNewline {
                break
            }

            if char == "]" {
                firstRigthFound = true
            }

            j += 1
        }

        var result = String()
        if leftFound && rigthFound {
            result =
                String(string[i...j])

            result = result
                .replacingOccurrences(of: "[[", with: "")
                .replacingOccurrences(of: "]]", with: "")

            return (result, NSRange(i...j))
        }

        return nil
    }

    private func complete(offset: Int? = nil, range: NSRange? = nil, text: String? = nil, replacementRange: NSRange? = nil) {
        var endPosition: UITextPosition = editArea.endOfDocument

        if let offset = offset,
            let position = editArea.position(from: editArea.beginningOfDocument, offset: offset) {
            endPosition = position
        }

        let rect = editArea.caretRect(for: endPosition)

        let customView = UIView(frame: CGRect(x: rect.origin.x, y: rect.origin.y + 30, width: 200, height: 0))
        editArea.addSubview(customView)

        dropDown.cellHeight = 35
        dropDown.textFont = UIFont.boldSystemFont(ofSize: 15)
        dropDown.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)
        dropDown.textColor = NightNight.theme == .night ? UIColor.white : UIColor.gray
        dropDown.anchorView = customView
        dropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            customView.removeFromSuperview()

            // WikiLinks
            if let range = replacementRange {
                guard
                    let textView = self.editArea,
                    let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                    let end = textView.position(from: start, offset: range.length),
                    let selectedRange = textView.textRange(from: start, to: end)
                else { return }

                self.editArea.replace(selectedRange, withText: item)
                self.editArea.selectedRange = NSRange(location: range.location + item.count + 2, length: 0)
                return
            }

            if let range = range, let text = text {
                let string = self.editArea.textStorage.mutableString.substring(with: range) + text

                let addText = item.replacingOccurrences(of: string, with: "")
                self.editArea.insertText(addText + " ")
            } else if text != nil {
                let addText = String(item.dropFirst())

                self.editArea.insertText(addText + " ")
            } else {
                self.editArea.insertText(item + " ")
            }
        }

        dropDown.show()
    }

    @objc public func scanTags() {
        guard UserDefaultsManagement.inlineTags else { return }
        guard let note = EditTextView.note else { return }

        UIApplication.getVC().sidebarTableView.loadTags(notes: [note])

        if UserDefaultsManagement.naming == .autoRename {
            let title = note.title.withoutSpecialCharacters.trunc(length: 64)

            if note.fileName != title && title.count > 0 {
                UIApplication.getVC().notesTable.rename(note: note, to: title, presentController: self)
            }
        }
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

        if UserDefaultsManagement.dynamicTypeFont {
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

            // Handoff needs update in cursor position cahnged
            userActivity?.needsSave = true
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
           let vc = pc.containerController.viewControllers[0] as? ViewController
        else { return }
        
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
        
        if note.type == .RichText {
            processor.higlightLinks()
        }

        // Prevent textStorage refresh in CloudDriveManager
        note.modifiedLocalAt = Date()
        let text = self.editArea.attributedText
        
        self.storageQueue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self] in
            guard let self = self else {return}

            if let text = text {

                if note.isEncrypted() && !note.isUnlocked() {
                    DispatchQueue.main.async {
                        self.cancel()
                    }

                    return
                }

                note.save(attributed: text)
                note.invalidateCache()
                note.loadPreviewInfo()
            }

            vc.updateSpotlightIndex(notes: [note])

            DispatchQueue.main.async {
                self.rowUpdaterTimer.invalidate()
                self.rowUpdaterTimer = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(self.updateCurrentRow), userInfo: nil, repeats: false)

                self.tagsTimer?.invalidate()
                self.tagsTimer = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(self.scanTags), userInfo: nil, repeats: false)
            }
        }
        self.storageQueue.addOperation(operation)
        
        if var font = UserDefaultsManagement.noteFont {
            if #available(iOS 11.0, *), UserDefaultsManagement.dynamicTypeFont {
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font)
            }

            editArea.typingAttributes.removeValue(forKey: .backgroundColor)
            editArea.typingAttributes[.font] = font
        }
        
        editArea.initUndoRedoButons()
        
        vc.cloudDriveManager?.metadataQuery.enableUpdates()
    }

    @objc private func updateCurrentRow() {
        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = pc.containerController.viewControllers[0] as? ViewController,
            let note = self.note
        else { return }

        vc.notesTable.moveRowUp(note: note)
    }
    
    func getSearchText() -> String {
        if let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = pc.containerController.viewControllers[0] as? ViewController,
            let search = vc.search.text {
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

        if let last = note.getLastSelectedRange() {
            editArea.selectedRange = last
        }

        restoreContentOffset()
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        initialKeyboardHeight = 0
        let contentInsets = UIEdgeInsets.zero
        editArea.contentInset = contentInsets
        editArea.scrollIndicatorInsets = contentInsets
    }

    public func resetToolbar() {
        toolbar = .none
    }

    func addToolBar(textField: UITextView, toolbar: UIToolbar) {
        let scrollFrame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: toolbar.frame.height)
        let scroll = UIScrollView(frame: scrollFrame)
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentSize = CGSize(width: toolbar.frame.width, height: toolbar.frame.height)
        scroll.addSubview(toolbar)

        let topBorder = CALayer()
        topBorder.frame = CGRect(x: -1000, y: 0, width: 9999, height: 1)
        topBorder.mixedBackgroundColor = MixedColor(normal: 0xD5D7DD, night: 0x373739)
        scroll.layer.addSublayer(topBorder)

        let isFirst = textField.isFirstResponder
        if isFirst {
            textField.endEditing(true)
        }

        let inputAccView = UIInputView(frame: scrollFrame, inputViewStyle: .keyboard)
        inputAccView.addSubview(scroll)
        textField.inputAccessoryView = scroll

        if isFirst {
            textField.becomeFirstResponder()
        }

        if let etv = textField as? EditTextView {
            etv.initUndoRedoButons()
        }
    }

    private func getMarkdownToolbar() -> UIToolbar {
        var items = [UIBarButtonItem]()

        let todoImage = UIImage(named: "toolbarTodo")?.resize(maxWidthHeight: 27)
        let todoButton = UIBarButtonItem(image: todoImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.todoPressed))
        items.append(todoButton)

        if UserDefaultsManagement.inlineTags {
            let tagImage = UIImage(named: "toolbarTag")?.resize(maxWidthHeight: 25)
            let tagButton = UIBarButtonItem(image: tagImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.tagPressed))
            items.append(tagButton)
        }

        let boldImage = UIImage(named: "toolbarBold")?.resize(maxWidthHeight: 21)
        let boldButton = UIBarButtonItem(image: boldImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.boldPressed))
        items.append(boldButton)

        let italicImage = UIImage(named: "toolbarItalic")?.resize(maxWidthHeight: 18)
        let italicButton = UIBarButtonItem(image: italicImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.italicPressed))
        italicButton.tag = 0x03
        items.append(italicButton)

        let headerImage = UIImage(named: "toolbarHeader")?.resize(maxWidthHeight: 22)
        let headerButton = UIBarButtonItem(image: headerImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.headerPressed))
        items.append(headerButton)

        let wikiImage = UIImage(named: "toolbarWiki")?.resize(maxWidthHeight: 25)
        let wikiButton = UIBarButtonItem(image: wikiImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.wikilink))
        items.append(wikiButton)

        let toolbarImage = UIImage(named: "toolbarImage")?.resize(maxWidthHeight: 26)
        let imageButton = UIBarButtonItem(image: toolbarImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.insertImage))
        items.append(imageButton)

        let codeBlockImage = UIImage(named: "codeBlockAsset")?.resize(maxWidthHeight: 24)
        let codeblockButton = UIBarButtonItem(image: codeBlockImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.codeBlockButton))
        items.append(codeblockButton)

        let quoteImage = UIImage(named: "quote")?.resize(maxWidthHeight: 21)
        let quoteButton = UIBarButtonItem(image: quoteImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.quotePressed))
        items.append(quoteButton)

        let orderedListImage = UIImage(named: "ordered_list")?.resize(maxWidthHeight: 25)
        let orderedListButton = UIBarButtonItem(image: orderedListImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.orderedListPressed))
        items.append(orderedListButton)

        let numberedListImage = UIImage(named: "numbered_list")?.resize(maxWidthHeight: 25)
        let numberedListButton = UIBarButtonItem(image: numberedListImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.numberedListPressed))
        items.append(numberedListButton)

        let indentRightImage = UIImage(named: "toolbarIndentRight")?.resize(maxWidthHeight: 25)
        let indentButton = UIBarButtonItem(image: indentRightImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.indentPressed))
        items.append(indentButton)

        let indentLeftImage = UIImage(named: "toolbarIndentLeft")?.resize(maxWidthHeight: 25)
        let unindentButton = UIBarButtonItem(image: indentLeftImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.unIndentPressed))
        items.append(unindentButton)

        let undoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "undo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.undoPressed))
        items.append(undoButton)

        let redoButton = UIBarButtonItem(image: #imageLiteral(resourceName: "redo.png"), landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.redoPressed))
        items.append(redoButton)

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

        let toolBar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: width, height: 40))
        toolBar.backgroundColor = .darkGray
        toolBar.isTranslucent = false
        toolBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        toolBar.setItems(items, animated: false)
        toolBar.isUserInteractionEnabled = true

        return toolBar
    }

    private func getRTFToolbar() -> UIToolbar {
        let width = self.editArea.superview!.frame.width
        let toolBar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: width, height: 44))

        toolBar.mixedBarTintColor = MixedColor(normal: 0xffffff, night: 0x272829)
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

    @objc func boldPressed(){
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.bold()
        }
    }

    @objc func tagPressed(){
        editArea.insertText("#")

        let location = editArea.selectedRange.location

        let vc = UIApplication.getVC()
        guard let project = vc.searchQuery.project else { return }
        let tags = vc.sidebarTableView.getAllTags(projects: [project])
        self.dropDown.dataSource = tags

        self.complete(offset: location)
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

    @objc func wikilink() {
        editArea.insertText("[[]]")
        let location = editArea.selectedRange.location - 2
        let range = NSRange(location: location, length: 0)
        editArea.selectedRange = range

        guard let titles = Storage.sharedInstance().getTitles() else { return }

        self.dropDown.dataSource = titles
        self.complete(offset: location, replacementRange: range)
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
            formatter.todo()
            
            AudioServicesPlaySystemSound(1519)
        }
    }

    @objc func orderedListPressed() {
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note, shouldScanMarkdown: false)
            formatter.list()

            AudioServicesPlaySystemSound(1519)
        }
    }

    @objc func numberedListPressed() {
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note, shouldScanMarkdown: false)
            formatter.orderedList()

            AudioServicesPlaySystemSound(1519)
        }
    }

    @objc func insertImage() {
        let actionSheet = UIAlertController(title: NSLocalizedString("Images source:", comment: ""), message: nil, preferredStyle: .actionSheet)

        let photos = UIAlertAction(title: NSLocalizedString("Photos", comment: ""), style: .default, handler: { _ in
            self.imagePressed()
        })
        actionSheet.addAction(photos)

        let iCloudDrive = UIAlertAction(title: NSLocalizedString("Documents", comment: ""), style: .default, handler: { _ in

            let documentPickerController = UIDocumentPickerViewController(documentTypes: [String(kUTTypeImage)], in: .import)
            documentPickerController.delegate = self
            documentPickerController.allowsMultipleSelection = true
            documentPickerController.modalPresentationStyle = .formSheet

            self.present(documentPickerController, animated: true, completion: nil)
        })

        actionSheet.addAction(iCloudDrive)

        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive, handler: { _ in
        })

        actionSheet.addAction(cancel)

        if let view = self.editArea.superview {
            actionSheet.popoverPresentationController?.sourceView = view
            actionSheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.size.width / 2.0, y: view.bounds.size.height, width: 2.0, height: 1.0)
        }

        present(actionSheet, animated: true, completion: nil)
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
                        if let uti = info?["PHImageFileUTIKey"] as? String,
                            let ext = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue()
                        {
                            imageExt = String(ext)
                        }

                        var url = URL(fileURLWithPath: "file:///tmp/" + UUID().uuidString + "." + imageExt)
                        var data: Data?

                        if let fileURL = info?["PHImageFileURLKey"] as? URL,
                            fileURL.pathExtension.lowercased() == "heic",
                            let imageUnwrapped = image
                        {
                            data = imageUnwrapped.jpegData(compressionQuality: 1);
                            url.deletePathExtension()
                            url.appendPathExtension("jpg")
                        } else if let fileData = info?["PHImageFileDataKey"] as? Data {
                            let format = ImageFormat.get(from: fileData)

                            if format == .heic {
                                data = UIImage(data: fileData)?.jpegData(compressionQuality: 1)
                                imageExt = "jpg"
                            } else {
                                data = fileData

                                let ext = ImageFormat.get(from: data!)
                                let path = "file:///tmp/" + UUID().uuidString + "." + ext.rawValue
                                url = URL(fileURLWithPath: path)
                            }
                        } else if let imageFileUrl = info?["PHImageFileURLKey"] as? URL {
                            do {
                                data = try Data(contentsOf: imageFileUrl)

                                let ext = ImageFormat.get(from: data!)
                                let path = "file:///tmp/" + UUID().uuidString + "." + ext.rawValue
                                url = URL(fileURLWithPath: path)
                            } catch {
                                return
                            }
                        }

                        guard let imageData = data else { return }

                        if UserDefaultsManagement.liveImagesPreview {
                            self.editArea.saveImageClipboard(data: imageData, note: note, ext: imageExt)

                            if processed == assets.count {
                                note.save(attributed: self.editArea.attributedText)

                                UIApplication.getVC().notesTable.reloadRowForce(note: note)
                                return
                            }

                            if assets.count != 1 {
                                self.editArea.insertText("\n\n")
                            }

                            return
                        }

                        guard let path = ImagesProcessor.writeFile(data: imageData, url: url, note: note, ext: imageExt) else { return }

                        markup += "![](\(path))\n\n"

                        guard processed == assets.count else { return }

                        DispatchQueue.main.async {
                            self.editArea.insertText(markup)

                            note.save(attributed: self.editArea.attributedText)
                            UIApplication.getVC().notesTable.reloadRowForce(note: note)
                            
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

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let note = self.note else { return }

        var processed = 0
        var markup = String()

        for url in urls {
            guard var data = try? Data(contentsOf: url) else { continue }

            processed += 1

            let format = ImageFormat.get(from: data)
            var imageExt = "jpg"

            switch format {
            case .heic:
                if let jpegData = UIImage(data: data)?.jpegData(compressionQuality: 1) {
                    data = jpegData
                }
            default:
                imageExt = format.rawValue
            }

            let url = URL(fileURLWithPath: "file:///tmp/" + UUID().uuidString + "." + imageExt)

            if UserDefaultsManagement.liveImagesPreview {
                self.editArea.saveImageClipboard(data: data, note: note, ext: imageExt)

                if processed == urls.count {
                    note.save(attributed: self.editArea.attributedText)

                    UIApplication.getVC().notesTable.reloadRowForce(note: note)
                    continue
                }

                if urls.count != 1 {
                    self.editArea.insertText("\n\n")
                }

                continue
            }

            guard let path = ImagesProcessor.writeFile(data: data, url: url, note: note, ext: imageExt) else { return }

             markup += "![](\(path))\n\n"

             guard processed == urls.count else { continue }

             DispatchQueue.main.async {
                 self.editArea.insertText(markup)

                 note.save(attributed: self.editArea.attributedText)
                 UIApplication.getVC().notesTable.reloadRowForce(note: note)

                 note.isParsed = false

                 self.editArea.undoManager?.removeAllActions()
                 self.refill()
             }
        }
    }

    @objc func preferredContentSizeChanged() {
        if let n = note {
            self.fill(note: n)
        }
    }
    
    @objc func undoPressed() {
        isUndoAction = true

        let evc = UIApplication.getEVC()

        guard let ea = evc.editArea,
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
        isUndoAction = true

        let evc = UIApplication.getEVC()
        guard let ea = evc.editArea,
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
            guard let path = self.editArea.textStorage.attribute(.link, at: characterIndex, effectiveRange: nil) as? String else { return }

            if path.starts(with: "fsnotes://find?id=") {
                openWikiLink(query: path)
                return
            }

//            if path.starts(with: "fsnotes://open/?tag=") {
//                if let url = URL(string: path) {
//                    UIApplication.shared.open(url, options: [:])
//                }
//
//                return
//            }

            if self.editArea.isFirstResponder {
                DispatchQueue.main.async {
                    self.editArea.selectedRange = NSRange(location: characterIndex, length: 0)
                }

                return
            }

            if let url = URL(string: path) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }


    }

    public func openWikiLink(query: String) {
        guard let query = query
            .replacingOccurrences(of: "fsnotes://find?id=", with: "")
            .removingPercentEncoding else { return }

        guard let note = note else { return }

        if let note = Storage.instance?.getBy(title: query, exclude: note) {
            fill(note: note)
        } else if let note = Storage.instance?.getBy(fileName: query, exclude: note) {
            fill(note: note)
        } else {

            guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
                let vc = pc.containerController.viewControllers[0] as? ViewController
            else { return }

            if let index = pc.containerController.selectedIndex {
                vc.shouldReturnToControllerIndex = index
            }

            pc.containerController.selectController(atIndex: 0, animated: true)

            vc.search.text = query
            vc.reloadNotesTable(with: SearchQuery(filter: query)) {
                if vc.searchView.isHidden {
                    vc.searchView.isHidden = false
                }

                vc.search.becomeFirstResponder()
            }
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

    public func getMoreButton() -> UIBarButtonItem {
        let menuBtn = UIButton(type: .custom)
        menuBtn.frame = CGRect(x: 0.0, y: 0.0, width: 32, height: 32)
        let image = UIImage(named: "more_row_action")!.resize(maxWidthHeight: 32)?.imageWithColor(color1: .white)

        menuBtn.setImage(image, for: .normal)
        menuBtn.addTarget(self, action: #selector(clickOnButton), for: UIControl.Event.touchUpInside)

        let menuBarItem = UIBarButtonItem(customView: menuBtn)
        let currWidth = menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 32)
        currWidth?.isActive = true
        let currHeight = menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 32)
        currHeight?.isActive = true

        menuBarItem.tintColor = UIColor.white
        return menuBarItem
    }

    public func getPreviewButton() -> UIBarButtonItem {
        let menuBtn = UIButton(type: .custom)
        menuBtn.frame = CGRect(x: 0.0, y: 0.0, width: 20, height: 20)
        let image = UIImage(named: "preview_editor_controller")!.imageWithColor(color1: .white)

        menuBtn.setImage(image, for: .normal)
        menuBtn.addTarget(self, action: #selector(preview), for: UIControl.Event.touchUpInside)

        let menuBarItem = UIBarButtonItem(customView: menuBtn)
        let currWidth = menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 24)
        currWidth?.isActive = true
        let currHeight = menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 24)
        currHeight?.isActive = true

        menuBarItem.tintColor = UIColor.white
        return menuBarItem
    }

    @objc public func cancel() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else { return }

        bvc.containerController.selectController(atIndex: 0, animated: true)
    }

    @objc public func preview() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController
        else { return }

        UserDefaultsManagement.previewMode = true

        editArea.endEditing(true)

        UIApplication.getPVC()?.loadPreview()
        bvc.containerController.selectController(atIndex: 2, animated: false)

        // Handoff needs update in cursor position cahnged
        userActivity?.needsSave = true
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {

        if URL.absoluteString.starts(with: "fsnotes://find?id=") {
            if interaction == .invokeDefaultAction {
                openWikiLink(query: URL.absoluteString)
            }
            return false
        }

        if URL.absoluteString.starts(with: "fsnotes://open/?tag=") {
            if interaction == .invokeDefaultAction {
                UIApplication.shared.open(URL, options: [:])
            }
//            if textView.isFirstResponder {
//                UIApplication.shared.open(URL, options: [:])
//            }

            return false
        }

        if textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.selectedRange = NSRange(location: characterRange.upperBound, length: 0)
            }

            if interaction == .presentActions {
                let pathKey = NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.path")
                if nil != textView.textStorage.attribute(pathKey, at: characterRange.location, effectiveRange: nil) {
                    return false
                }

                return true
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

    func textViewDidEndEditing(_ textView: UITextView) {
        initialKeyboardHeight = 0
    }

    private func restoreContentOffset() {
        if let co = self.editArea.lastContentOffset {
           self.editArea.lastContentOffset = nil
           self.editArea.setContentOffset(co, animated: false)
       }
    }

    public func saveContentOffset() {
        if editArea != nil {
            editArea.lastContentOffset = editArea.contentOffset
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard UserDefaultsManagement.nightModeType == .system else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkDarkMode()
        }
    }

    public func checkDarkMode() {
        if #available(iOS 12.0, *) {
            if traitCollection.userInterfaceStyle == .dark {
                if NightNight.theme != .night {
                    UIApplication.getVC().enableNightMode()
                }
            } else {
                if NightNight.theme == .night {
                    UIApplication.getVC().disableNightMode()
                }
            }
        }
    }

    /*
     Handoff methods
     */
    public func registerHandoff(for note: Note) {
        let updateDict:  [String: String] = ["note-file-name": note.name]
        let activity = NSUserActivity(activityType: "es.fsnot.handoff-open-note")
        activity.isEligibleForHandoff = true
        activity.addUserInfoEntries(from: updateDict)
        activity.title = NSLocalizedString("Open note", comment: "Document opened")
        self.userActivity = activity
        self.userActivity?.becomeCurrent()
    }

    public func load(note: Note) {
        let index = UserDefaultsManagement.previewMode ? 2 : 1
        let evc = UIApplication.getEVC()
        evc.editArea.resignFirstResponder()
        evc.fill(note: note, clearPreview: true, enableHandoff: false) {
            guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else {
                return
            }
            bvc.containerController.selectController(atIndex: index, animated: true)
        }
    }

    override func restoreUserActivityState(_ activity: NSUserActivity) {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else {
            return
        }

        if let id = activity.userInfo?["kCSSearchableItemActivityIdentifier"] as? String {
            let url = URL(fileURLWithPath: id)
            if let note = Storage.shared().getBy(url: url) {
                load(note: note)
                return
            } else {
                UIApplication.getVC().restoreActivity = url
            }
        }

        guard let name = activity.userInfo?["note-file-name"] as? String,
            let position = activity.userInfo?["position"] as? String,
            let state = activity.userInfo?["state"] as? String,
            let note = Storage.sharedInstance().getBy(name: name)
        else { return }

        var index = 0
        if state == "preview" {
            UserDefaultsManagement.previewMode = true
            index = 2
        } else {
            UserDefaultsManagement.previewMode = false
            index = 1
        }

        let evc = UIApplication.getEVC()
        evc.editArea.resignFirstResponder()

        evc.fill(note: note, clearPreview: true, enableHandoff: false) {
            bvc.containerController.selectController(atIndex: index, animated: true)

            if let pos = Int(position), pos > -1, evc.editArea.textStorage.length >= pos {
                evc.editArea.becomeFirstResponder()
                evc.editArea.selectedRange = NSRange(location: pos, length: 0)
            }
        }
    }

    override func updateUserActivityState(_ activity: NSUserActivity) {
        guard let note = EditTextView.note else { return }

        let position =
            editArea.isFirstResponder ? editArea.selectedRange.location : -1
        let state = UserDefaultsManagement.previewMode ? "preview" : "editor"
        let data =
            [
                "note-file-name": note.name,
                "position": String(position),
                "state": state
            ]

        activity.addUserInfoEntries(from: data)
    }
}
