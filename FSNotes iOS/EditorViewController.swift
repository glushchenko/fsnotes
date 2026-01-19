//
//  EditorViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/31/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import AudioToolbox
import MobileCoreServices
import Photos
import DropDown
import CoreSpotlight
import PhotosUI

class EditorViewController: UIViewController,
    UITextViewDelegate,
    UIDocumentPickerDelegate,
    UIGestureRecognizerDelegate,
    PHPickerViewControllerDelegate,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    UISearchBarDelegate
{
    public var note: Note?
    public var quickLookURL: URL?

    private var isUndo = false
    private let storageQueue = OperationQueue()

    var inProgress = false
    var change = 0

    public var undoBarButton: UIBarButtonItem?
    public var redoBarButton: UIBarButtonItem?

    @IBOutlet weak var editArea: EditTextView!

    var rowUpdaterTimer = Timer()

    public var tagsTimer: Timer?
    private let dropDown = DropDown()

    private var isLandscape: Bool?
    
    // Search toolbar
    var keyboardAnchor: UITextField?
    var counterLabel: UILabel?
    var searchBar: UISearchBar?
    var searchToolbar: UIToolbar?
    var searchRanges: [NSRange] = []
    var currentSearchIndex: Int = 0
    var originalSelectedRange: NSRange?
    var originalBackgrounds: [NSRange: UIColor?] = [:]

    override func viewDidLoad() {
        storageQueue.maxConcurrentOperationCount = 1
        storageQueue.qualityOfService = .userInitiated

        editArea.textContainerInset = UIEdgeInsets(top: 13, left: 10, bottom: 0, right: 10)

        let imageTap = SingleImageTouchDownGestureRecognizer(target: self, action: #selector(imageTapHandler(_:)))
        editArea.addGestureRecognizer(imageTap)

        let tap = SingleTouchDownGestureRecognizer(target: self, action: #selector(tapHandler(_:)))
        editArea.addGestureRecognizer(tap)

        editArea.initTextStorage()

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(editMode))
        tapGR.delegate = self
        tapGR.numberOfTapsRequired = 2
        view.addGestureRecognizer(tapGR)

        editArea.imagesLoaderQueue.maxConcurrentOperationCount = 1
        editArea.imagesLoaderQueue.qualityOfService = .userInteractive

        super.viewDidLoad()
        
        var items = [UIBarButtonItem]()
        items.append(UIBarButtonItem(systemImageName: "magnifyingglass", target: self, selector: #selector(editorSearch)))
        items.append(UIBarButtonItem.flexibleSpace())
        items.append(UIBarButtonItem(systemImageName: "plus", target: self, selector: #selector(newNote)))

        toolbarItems = items

        self.addToolBar(textField: editArea, toolbar: self.getMarkdownToolbar())

        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: UIContentSizeCategory.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refill), name: NSNotification.Name(rawValue: "es.fsnot.external.file.changed"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        editArea.keyboardDismissMode = .interactive
    }

    @objc func rotated() {
        guard isLandscape != nil else {
            isLandscape = UIDevice.current.orientation.isLandscape
            return
        }

        let isLand = UIDevice.current.orientation.isLandscape
        if let landscape = self.isLandscape, landscape != isLand, !UIDevice.current.orientation.isFlat {
            isLandscape = isLand
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        editArea.isScrollEnabled = true

        super.viewDidAppear(animated)

        if editArea.textStorage.length == 0  && editArea.note?.previewState == false {
            editArea.perform(#selector(becomeFirstResponder), with: nil, afterDelay: 0)
        }

        initLinksColor()
        editArea.flashScrollIndicators()

        self.registerForKeyboardNotifications()

        initSwipes()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        configureNavMenu()
        
        navigationItem.largeTitleDisplayMode = .never

        navigationController?.setToolbarHidden(false, animated: true)
        navigationController?.toolbar.tintColor = UIColor.mainTheme
        navigationController?.navigationBar.tintColor = UIColor.mainTheme
    }

    @objc func search() {
        UIApplication.getVC().enableSearchFocus()

        self.cancel()
    }

    @objc func newNote() {
        UIApplication.getVC().createNote(content: "")

        configureNavMenu()
    }

    override func viewWillDisappear(_ animated: Bool) {
        editArea.endEditing(true)

        UIApplication.getNC()?.navigationItem.searchController = nil
    }

    override var disablesAutomaticKeyboardDismissal: Bool {
        return false
    }

    override var textInputMode: UITextInputMode? {
        if let keyboard = UserDefaultsManagement.defaultKeyboard {
            for mode in UITextInputMode.activeInputModes {
                if mode.primaryLanguage == keyboard  {
                    return mode
                }
            }
        }
        
        return super.textInputMode
    }

    private func registerForKeyboardNotifications(){
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    public func configureNavMenu() {
        guard let note = self.note else { return }
        guard let menu = UIApplication.getVC().notesTable.makeBulkMenu(editor: true, note: note) else { return }

        let buttonName =
            editArea.note?.previewState == true
                ? "eye.slash"
                : "eye"

        let previewBarItem = UIBarButtonItem(systemImageName: buttonName, target: self, selector: #selector(togglePreview))
        previewBarItem.tag = 5

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(systemImageName: "ellipsis.circle", menu: menu),
            previewBarItem
        ]
    }

    public func fill(note: Note, selectedRange: NSRange? = nil, clearPreview: Bool = false, enableHandoff: Bool = true, completion: (() -> ())? = nil) {

        if enableHandoff {
            registerHandoff(for: note)
        }

        self.note = note
        if !note.isLoaded {
            note.load()
        }
        
        editArea.note = note

        if note.previewState {
            loadPreviewView()
            completion?()
            return
        }

        getPreviewView()?.removeFromSuperview()
        fillEditor(note: note, selectedRange: selectedRange)
        completion?()
    }

    private func fillEditor(note: Note, selectedRange: NSRange? = nil) {
        guard editArea != nil else { return }

        editArea.isNoteLoading = true
        editArea.initUndoRedoButons()

        view.backgroundColor = UIColor.dropDownColor
        editArea.backgroundColor = UIColor.dropDownColor

        if let content = note.content.mutableCopy() as? NSMutableAttributedString {
            editArea.attributedText = content
        }
        
        if let scroll = editArea.inputAccessoryView as? UIScrollView {
            scroll.contentOffset = .zero
        }
        
        editArea.delegate = self

        let storage = editArea.textStorage
        storage.updateCheckboxList()
        editArea.typingAttributes[.font] = UserDefaultsManagement.noteFont
        
        editArea.layoutManager.ensureLayout(for: editArea.textContainer)
        editArea.layoutIfNeeded()
        
        self.loadSelectedRange()
        
        if let query = self.getSearchText(), query.count > 0 {
            UIApplication.getVC().enableSearchFocus(string: query)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.openSearchWithText(query)
            }
        }
    }

    @objc public func clickOnButton() {
        let vc = UIApplication.getVC()
        guard let note = self.note else { return }

        vc.notesTable.actionsSheet(notes: [note], showAll: true, presentController: self)
    }
    
    @objc func refill() {
        guard let editArea = editArea else { return }

        initLinksColor()
        
        if let note = self.note {
            let keyboardIsOpen = editArea.isFirstResponder
            
            if keyboardIsOpen {
                editArea.endEditing(true)
            }

            fill(note: note)

            if keyboardIsOpen {
                _ = editArea.becomeFirstResponder()
            }
        }
    }
    
    private var keyboardFrameChangeCount = 0
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        keyboardFrameChangeCount += 1
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let note = self.note else { return true }

        tagsHandler(affectedCharRange: range, text: text)
        wikilinkHandler(textView: textView, text: text)
        deleteUnusedImages(checkRange: range)

        // New line
        if text == "\n" {
            let formatter = TextFormatter(textView: self.editArea, note: note)
            formatter.newLine()

            return false
        }

        // Tab
        if text == "\t" {
            let formatter = TextFormatter(textView: self.editArea, note: note)
            formatter.tabKey()

            return false
        }

        if let font = self.editArea.typingFont {
            editArea.typingAttributes.removeAll()
            editArea.typingAttributes[.font] = font
        }

        return true
    }

    private func tagsHandler(affectedCharRange: NSRange, text: String) {
        guard UserDefaultsManagement.inlineTags else { return }

        let textStorage = editArea.textStorage

        // close dropdown
        if ["", " ", "\t", "\n"].contains(text) {
            if !dropDown.isHidden {
                dropDown.hide()
            }
            return
        }

        // one char
        guard text.count == 1 else { return }

        let nextCharLocation = affectedCharRange.location + 1
        let nextChar: String

        if editArea.selectedRange.length == 0, nextCharLocation <= textStorage.length {
            let nextCharRange = NSRange(location: affectedCharRange.location, length: 1)
            nextChar = textStorage.mutableString.substring(with: nextCharRange)
        } else {
            nextChar = " "
        }

        if affectedCharRange.location > 0 {
            let hashRange = NSRange(location: affectedCharRange.location - 1, length: 1)
            let prevChar = (textStorage.string as NSString).substring(with: hashRange)

            if prevChar == "#" && nextChar.isWhitespace {
                let filteredTags = self.getAllTags().filter { $0.lowercased().starts(with: text.lowercased()) }

                if filteredTags.isEmpty {
                    dropDown.hide()
                } else {
                    dropDown.dataSource = filteredTags
                    complete(offset: hashRange.location, text: text)
                }
                return
            }
        }

        let parRange = textStorage.mutableString.paragraphRange(for: NSRange(location: affectedCharRange.location, length: 0))
        textStorage.mutableString.enumerateSubstrings(in: parRange, options: .byWords) { word, range, _, stop in
            guard let word = word,
                  affectedCharRange.location <= range.upperBound,
                  affectedCharRange.location >= range.lowerBound,
                  range.location > 0 else {
                return
            }

            let hashRange = NSRange(location: range.location - 1, length: 1)
            let prevChar = (textStorage.string as NSString).substring(with: hashRange)

            if prevChar == "#" && nextChar.isWhitespace {
                let searchText = word + text
                let filteredTags = self.getAllTags().filter { $0.lowercased().starts(with: searchText.lowercased()) }

                if filteredTags.isEmpty {
                    self.dropDown.hide()
                } else {
                    self.dropDown.dataSource = filteredTags
                    self.complete(offset: hashRange.location, range: range, text: text)
                }

                stop.pointee = true
            }
        }
    }

    private func getAllTags() -> [String] {
        let vc = UIApplication.getVC()
        var projects = [Project]()
        if let project = Storage.shared().searchQuery.projects.first {
            projects.append(project)
        } else {
            projects = Storage.shared().getProjects()
        }
        let allTags = vc.sidebarTableView.getAllTags(projects: projects)

        return allTags
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
        dropDown.backgroundColor = UIColor.dropDownColor
        dropDown.textColor = traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.gray
        dropDown.anchorView = customView
        dropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            customView.removeFromSuperview()

            // WikiLinks
            if let replacementRange = replacementRange {
                editArea.undoManager?.beginUndoGrouping()
                self.editArea.selectedRange = replacementRange
                self.editArea.insertText(item)
                editArea.undoManager?.endUndoGrouping()
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
        guard let note = editArea.note else { return }

        UIApplication.getVC().sidebarTableView.loadTags(notes: [note])

        if let title = note.getAutoRenameTitle() {
            UIApplication.getVC().notesTable.rename(note: note, to: title)
        }
    }

    private func deleteUnusedImages(checkRange: NSRange) {
        editArea.textStorage.enumerateAttribute(.attachment, in: checkRange) { (value, range, _) in
            guard let meta = editArea.textStorage.getMeta(at: range.location) else { return }

            do {
                if let data = try? Data(contentsOf: meta.url) {
                    editArea.textStorage.addAttribute(.attachmentSave, value: data, range: range)

                    try FileManager.default.removeItem(at: meta.url)
                }
            } catch {
                print(error)
            }
        }
    }

    private func deleteBackwardPressed(text: String) -> Bool {
        if !self.isUndo, let char = text.cString(using: String.Encoding.utf8), strcmp(char, "\\b") == -92 {
            return true
        }
        
        self.isUndo = false
        
        return false
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        if textView.isFirstResponder {
            // Handoff needs update in cursor position cahnged
            userActivity?.needsSave = true
            
            saveSelectedRange()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        saveSelectedRange()
    }

    func textViewDidChange(_ textView: UITextView) {
        let vc = UIApplication.getVC()
        
        //vc.cloudDriveManager?.metadataQuery.disableUpdates()
        
        guard let note = self.note else { return }

        // Prevent textStorage refresh in CloudDriveManager
        note.modifiedLocalAt = Date()
        self.storageQueue.cancelAllOperations()

        let text = self.editArea.attributedText.mutableCopy() as? NSMutableAttributedString

        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self] in
            guard let self = self, let text = text else {return}

            note.save(content: text)

            if note.isEncrypted() && !note.isUnlocked() {
                DispatchQueue.main.async {
                    self.cancel()
                }

                return
            }

            note.invalidateCache()
            note.loadPreviewInfo()

            vc.updateSpotlightIndex(notes: [note])

            DispatchQueue.main.async {
                self.rowUpdaterTimer.invalidate()
                self.rowUpdaterTimer = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(self.updateCurrentRow), userInfo: nil, repeats: false)

                self.tagsTimer?.invalidate()
                self.tagsTimer = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(self.scanTags), userInfo: nil, repeats: false)
            }

            usleep(100000)
        }
        self.storageQueue.addOperation(operation)

        editArea.typingAttributes.removeValue(forKey: .backgroundColor)
        editArea.typingAttributes[.font] = UserDefaultsManagement.noteFont
        editArea.initUndoRedoButons()
        
        //vc.cloudDriveManager?.metadataQuery.enableUpdates()
    }

    @objc private func updateCurrentRow() {
        let vc = UIApplication.getVC()
        guard let note = self.note else { return }

        vc.notesTable.moveRowUp(note: note)
        vc.notesTable.reloadRows(notes: [note])
    }
    
    func getSearchText() -> String? {
        if let search = UIApplication.getVC().navigationItem.searchController?.searchBar.text {
            return search
        }

        return nil
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        keyboardFrameChangeCount = 0
        
        guard let userInfo = notification.userInfo else { return }
        guard var keyboardFrame: CGRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }

        keyboardFrame = view.convert(keyboardFrame, from: nil)
        let keyboardHeight = keyboardFrame.height

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
            self.editArea.typingAttributes[.paragraphStyle] = paragraphStyle
            self.editArea.typingAttributes.removeValue(forKey: .link)

            let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardHeight - 66, right: 0.0)
            self.editArea.contentInset = contentInsets
            self.editArea.scrollIndicatorInsets = contentInsets
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        editArea.contentInset = contentInsets
        editArea.scrollIndicatorInsets = contentInsets
        
        if isKeyboardClosedManually() {
            
            // NO selection more
            saveSelectedRangeZero()
        }
        
        if searchBar != nil {
            hideSearch()
        }
    }
    
    func isKeyboardClosedManually() -> Bool {
        return keyboardFrameChangeCount > 2
    }

    func addToolBar(textField: UITextView, toolbar: UIToolbar) {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentSize = CGSize(width: toolbar.frame.width, height: 50)
        scroll.addSubview(toolbar)
        toolbar.frame.origin = .zero
        textField.inputAccessoryView = scroll
    }

    public func getMarkdownToolbar() -> UIToolbar {
        if #available(iOS 26.0, *) {
            return getModernToolbar()
        } else {
            return getLegacyToolbar()
        }
    }
    
    public func getModernToolbar() -> UIToolbar {
        var items = [UIBarButtonItem]()

        let todoButton = UIBarButtonItem(systemImageName: "checkmark.square", target: self, selector: #selector(EditorViewController.todoPressed))
        items.append(todoButton)

        if UserDefaultsManagement.inlineTags {
            let tagButton = UIBarButtonItem(systemImageName: "tag", target: self, selector: #selector(EditorViewController.tagPressed))
            items.append(tagButton)
        }

        let boldButton = UIBarButtonItem(systemImageName: "bold", target: self, selector: #selector(EditorViewController.boldPressed))
        items.append(boldButton)

        let italicButton = UIBarButtonItem(systemImageName: "italic", target: self, selector: #selector(EditorViewController.italicPressed))
        italicButton.tag = 0x03
        items.append(italicButton)

        let headerButton = UIBarButtonItem(systemImageName: "textformat", target: self, selector: #selector(EditorViewController.headerPressed))
        items.append(headerButton)

        let wikiButton = UIBarButtonItem(systemImageName: "link", target: self, selector: #selector(EditorViewController.wikilink))
        items.append(wikiButton)

        let imageButton = UIBarButtonItem(systemImageName: "paperclip", target: self, selector: #selector(EditorViewController.insertFile))
        items.append(imageButton)

        let codeblockButton = UIBarButtonItem(systemImageName: "swift", target: self, selector: #selector(EditorViewController.codeBlockButton))
        items.append(codeblockButton)

        let quoteButton = UIBarButtonItem(systemImageName: "quote.bubble", target: self, selector: #selector(EditorViewController.quotePressed))
        items.append(quoteButton)

        let orderedListButton = UIBarButtonItem(systemImageName: "list.bullet", target: self, selector: #selector(EditorViewController.orderedListPressed))
        items.append(orderedListButton)

        let numberedListButton = UIBarButtonItem(systemImageName: "list.number", target: self, selector: #selector(EditorViewController.numberedListPressed))
        items.append(numberedListButton)

        let indentButton = UIBarButtonItem(systemImageName: "increase.indent", target: self, selector: #selector(EditorViewController.indentPressed))
        items.append(indentButton)

        let unindentButton = UIBarButtonItem(systemImageName: "decrease.indent", target: self, selector: #selector(EditorViewController.unIndentPressed))
        items.append(unindentButton)

        self.undoBarButton = UIBarButtonItem(systemImageName: "arrow.uturn.backward", target: self, selector: #selector(EditorViewController.undoPressed))
        items.append(self.undoBarButton!)

        self.redoBarButton = UIBarButtonItem(systemImageName: "arrow.uturn.forward", target: self, selector: #selector(EditorViewController.redoPressed))
        items.append(self.redoBarButton!)

        var totalWidth: CGFloat = 0
        for item in items {
            if item.tag == 0x03 {
                item.width = 30
                totalWidth += 30
            } else {
                item.width = 54
                totalWidth += 54
            }
        }

        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: totalWidth, height: 50))
        toolBar.setItems(items, animated: false)
        toolBar.isUserInteractionEnabled = true

        let appearance = UIToolbarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .darkGray
        appearance.shadowColor = .clear
        toolBar.standardAppearance = appearance
        toolBar.scrollEdgeAppearance = appearance

        return toolBar
    }
    
    private func getLegacyToolbar() -> UIToolbar {
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
        let imageButton = UIBarButtonItem(image: toolbarImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.insertFile))
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

        let undoImage = UIImage(named: "undo")?.resize(maxWidthHeight: 25)
        let undoButton = UIBarButtonItem(image: undoImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.undoPressed))
        items.append(undoButton)

        let redoImage = UIImage(named: "redo")?.resize(maxWidthHeight: 25)
        let redoButton = UIBarButtonItem(image: redoImage, landscapeImagePhone: nil, style: .done, target: self, action: #selector(EditorViewController.redoPressed))
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

        let toolBar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: width, height: 50))
        toolBar.backgroundColor = .darkGray
        toolBar.isTranslucent = false
        toolBar.tintColor = UIColor.mainTheme
        toolBar.setItems(items, animated: false)
        toolBar.isUserInteractionEnabled = true

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
        
        var projects = [Project]()
        if let project = Storage.shared().searchQuery.projects.first {
            projects.append(project)
        } else {
            projects = Storage.shared().getProjects()
        }
        
        let tags = vc.sidebarTableView.getAllTags(projects: projects)
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
        guard let note = note else { return }

        let formatter = TextFormatter(textView: editArea, note: note)
        formatter.wikiLink()

        guard let titles = Storage.shared().getTitles() else { return }

        self.dropDown.dataSource = titles
        self.complete(offset: editArea.selectedRange.location, replacementRange: editArea.selectedRange)
    }

    @objc func codeBlockButton() {
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.codeBlock()
        }
    }

    @objc func quotePressed() {
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
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
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.list()

            AudioServicesPlaySystemSound(1519)
        }
    }

    @objc func numberedListPressed() {
        if let note = note {
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.orderedList()

            AudioServicesPlaySystemSound(1519)
        }
    }

    @objc func insertFile() {
        let actionSheet = UIAlertController(title: NSLocalizedString("Images source:", comment: ""), message: nil, preferredStyle: .actionSheet)

        let photos = UIAlertAction(title: NSLocalizedString("Photos", comment: ""), style: .default, handler: { _ in
            var conf = PHPickerConfiguration(photoLibrary: .shared())
            conf.selectionLimit = 10

            let picker = PHPickerViewController(configuration: conf)
            picker.delegate = self

            self.present(picker, animated: true, completion: nil)
        })
        actionSheet.addAction(photos)

        let iCloudDrive = UIAlertAction(title: NSLocalizedString("Documents", comment: ""), style: .default, handler: { _ in

            let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
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

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let mutable = NSMutableAttributedString.build(data: data, preferredName: url.lastPathComponent) else { continue }

            DispatchQueue.main.async {
                self.editArea.insertAttributedText(mutable)
            }
        }
    }

    @objc func preferredContentSizeChanged() {
        if let n = note {
            self.fill(note: n)
        }
    }
    
    @objc func undoPressed() {
        guard let ea = UIApplication.getEVC().editArea, let um = ea.undoManager else { return }
        um.undo()
        ea.initUndoRedoButons()
    }
    
    @objc func redoPressed() {
        guard let ea = UIApplication.getEVC().editArea, let um = ea.undoManager else { return }
        um.redo()
        ea.initUndoRedoButons()
    }

    func initLinksColor() {
        var linkAttributes: [NSAttributedString.Key : Any] = [
            .foregroundColor: UIColor.linksColor
        ]

        linkAttributes[.underlineColor] = UIColor.lightGray
        linkAttributes[.underlineStyle] = 0
        
        if editArea != nil {
            editArea.linkTextAttributes = linkAttributes
        }
    }

    @objc private func tapHandler(_ sender: SingleTouchDownGestureRecognizer) {
        let myTextView = sender.view as! EditTextView
        guard let characterIndex = sender.touchCharIndex else { return}
        let char = myTextView.textStorage.mutableString.substring(with: NSRange(location: characterIndex, length: 1))

        // Toggle todo on click
        if characterIndex + 1 < myTextView.textStorage.length, char != "\n", self.isTodo(location: characterIndex, textView: myTextView), let note = self.note {

            let textFormatter = TextFormatter(textView: self.editArea!, note: note)
            textFormatter.toggleTodo(characterIndex)

            self.editArea.selectedTextRange = sender.selectedRange
            
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
                self.editArea.isAllowedScrollRect = true
            }

            AudioServicesPlaySystemSound(1519)
            return
        }

        // Image preview/selection on click
        if self.editArea.isImage(at: characterIndex) {
            guard let meta = myTextView.textStorage.getMeta(at: characterIndex) else { return }

            if let data = try? Data(contentsOf: meta.url), let someImage = UIImage(data: data) {
                let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
                let imagePreviewViewController = storyBoard.instantiateViewController(withIdentifier: "imagePreviewViewController") as! ImagePreviewViewController

                imagePreviewViewController.image = someImage
                imagePreviewViewController.url = meta.url
                imagePreviewViewController.note = note
                
                navigationController?.pushViewController(imagePreviewViewController, animated: true)
            } else if (FileManager.default.fileExists(atPath: meta.url.path)) {
                quickLook(url: meta.url)
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

            if path.starts(with: "fsnotes://open/?tag=") {
                if let url = URL(string: path) {
                    UIApplication.shared.open(url, options: [:])
                }
                return
            }

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
            let vc = UIApplication.getVC()

            navigationController?.popViewController(animated: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                vc.shouldReturnToControllerIndex = true
                vc.loadSearchController(query: query)
                vc.buildSearchQuery()
                vc.reloadNotesTable()
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
        let config = UIImage.SymbolConfiguration(pointSize: 23, weight: .light, scale: .default)
        let image = UIImage(systemName: "ellipsis.circle", withConfiguration: config)
        let menuBarItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(clickOnButton))
        menuBarItem.tintColor = UIColor.mainTheme

        return menuBarItem
    }

    @IBAction func editMode() {
        if editArea.note?.previewState == true {
            togglePreview()

            _ = editArea.becomeFirstResponder()
        }
    }

    public func getPreviewView() -> MPreviewView? {
        for sub in self.view.subviews {
            if sub.isKind(of: MPreviewView.self) {
                if let view = sub as? MPreviewView {
                    return view
                }
            }
        }

        return nil
    }

    @objc public func cancel() {
        navigationController?.popViewController(animated: true)
    }

    @objc public func togglePreview() {
        guard let unwrappedNote = self.note, let note = Storage.shared().getBy(url: unwrappedNote.url) else { return }
        
        note.loadPreviewState()
        
        if note.previewState {
            note.previewState = false
            getPreviewView()?.removeFromSuperview()
            fillEditor(note: note)

        } else {
            note.previewState = true
            editArea.endEditing(true)
            loadPreviewView()
        }

        let buttonName = note.previewState ? "eye.slash" : "eye"

        if let buttonBar = navigationItem.rightBarButtonItems?.first(where: { $0.tag == 5 }),
           let button = buttonBar.customView as? UIButton {

            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .light, scale: .default)
            let image = UIImage(systemName: buttonName, withConfiguration: config)?.imageWithColor(color1: UIColor.mainTheme)
            button.setImage(image, for: .normal)
        }

        // Handoff needs update in cursor position changed
        userActivity?.needsSave = true

        note.project.saveNotesPreview()
    }

    public func loadPreviewView() {
        guard let note = editArea.note else { return }

        var previewView: MPreviewView?
        previewView = getPreviewView()

        if previewView == nil {
            let newView = MPreviewView(frame: self.view.frame, note: note, closure: {})
            newView.backgroundColor = UIColor.dropDownColor
            view.addSubview(newView)

            newView.translatesAutoresizingMaskIntoConstraints = false
            view.leadingAnchor.constraint(equalTo: newView.leadingAnchor).isActive = true
            view.trailingAnchor.constraint(equalTo: newView.trailingAnchor).isActive = true
            view.topAnchor.constraint(equalTo: newView.topAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: newView.bottomAnchor).isActive = true
        }

        guard let previewView = previewView else { return }

        previewView.clean()
        previewView.load(note: note, force: true)
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
        editArea.keyboardIsOpened = true
        editArea.callCounter = 0
    }

    /*
     Handoff methods
     */
    public func registerHandoff(for note: Note) {
        let updateDict:  [String: String] = ["note-file-name": note.name]
        let activity = NSUserActivity(activityType: "es.fsnot.handoff-open-note")
        activity.isEligibleForHandoff = true
        activity.addUserInfoEntries(from: updateDict)
        activity.title = NSLocalizedString("Open Note", comment: "Document opened")
        self.userActivity = activity
        self.userActivity?.becomeCurrent()
    }

    public func load(note: Note) {
        let evc = UIApplication.getEVC()
        evc.editArea.resignFirstResponder()
        evc.fill(note: note, clearPreview: true, enableHandoff: false) {
            UIApplication.getVC().openEditorViewController()
        }
    }

    override func restoreUserActivityState(_ activity: NSUserActivity) {
        if let id = activity.userInfo?["kCSSearchableItemActivityIdentifier"] as? String {
            let url = URL(fileURLWithPath: id)
            
            var note = Storage.shared().getBy(url: url)
            if nil === note {
                note = Storage.shared().addNote(url: url)
            }
            
            if let note = note {
                load(note: note)
            }
            
            return
        }

        guard let name = activity.userInfo?["note-file-name"] as? String,
            let position = activity.userInfo?["position"] as? String,
            let note = Storage.shared().getBy(name: name)
        else { return }

        let evc = UIApplication.getEVC()
        evc.editArea.resignFirstResponder()

        evc.fill(note: note, clearPreview: true, enableHandoff: false) {
            UIApplication.getVC().openEditorViewController()

            if let pos = Int(position), pos > -1, evc.editArea.textStorage.length >= pos {
                evc.editArea.becomeFirstResponder()
                evc.editArea.selectedRange = NSRange(location: pos, length: 0)
            }
        }
    }

    override func updateUserActivityState(_ activity: NSUserActivity) {
        guard let note = editArea.note else { return }

        let position =
            editArea.isFirstResponder ? editArea.selectedRange.location : -1
        let state = note.previewState ? "preview" : "editor"
        let data =
            [
                "note-file-name": note.name,
                "position": String(position),
                "state": state
            ]

        activity.addUserInfoEntries(from: data)
    }

    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)

        for result in results {
            result.itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { (object, error) in
                guard let photo = object as? UIImage, let imageData = photo.jpgData else { return }

                let attachment = NSTextAttachment()
                let mutable = NSMutableAttributedString(attachment: attachment)
                mutable.addAttributes([
                    .attachmentSave: imageData,
                    .attachmentUrl: URL(fileURLWithPath: "/tmp/" + UUID().uuidString + ".jpg"),
                    .attachmentPath: String()
                ], range: NSRange(location: 0, length: 1))

                mutable.append(NSAttributedString(string: "\n\n"))

                DispatchQueue.main.async {
                    self.editArea.insertAttributedText(mutable)
                }
            })
        }
    }

    // Swipe controller from UITextView center
    // https://stackoverflow.com/questions/22244688/navigation-pop-view-when-swipe-right-like-instagram-iphone-app-how-i-achieve-thi/22244990#22244990
    
    public func initSwipes() {
        guard let popGestureRecognizer = self.navigationController?.interactivePopGestureRecognizer else { return }
        if let targets = popGestureRecognizer.value(forKey: "targets") as? NSMutableArray {
            let gestureRecognizer = UIPanGestureRecognizer()
            gestureRecognizer.setValue(targets, forKey: "targets")
            self.view.gestureRecognizers?.removeAll()
            self.view.addGestureRecognizer(gestureRecognizer)

            let tapGR = UITapGestureRecognizer(target: self, action: #selector(editMode))
            tapGR.delegate = self
            tapGR.numberOfTapsRequired = 2
            self.view.addGestureRecognizer(tapGR)
        }
    }
    
    func saveSelectedRangeZero() {
        guard let note = editArea.note, !editArea.isNoteLoading else { return }
        note.setSelectedRange(range: nil)
        saveScrollPosition()
    }

    func saveScrollPosition() {
        guard let note = editArea.note, !editArea.isNoteLoading else { return }
        
        let layoutManager = editArea.layoutManager
        let visibleY = editArea.contentOffset.y
        
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: CGRect(x: 0, y: visibleY, width: editArea.bounds.width, height: 1),
            in: editArea.textContainer
        )
        
        guard glyphRange.location != NSNotFound else { return }
        
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphRange.location, length: 1),
            in: editArea.textContainer
        )
        
        note.scrollPosition = charIndex
        note.scrollOffset = visibleY - glyphRect.minY
    }

    func saveSelectedRange() {
        guard let note = editArea.note, !editArea.isNoteLoading else { return }
        note.setSelectedRange(range: editArea.isFirstResponder ? editArea.selectedRange : nil)
        saveScrollPosition()
    }

    func loadSelectedRange() {
        guard let note = editArea.note else { return }
        
        if let range = note.getSelectedRange(), range.upperBound <= editArea.textStorage.length {
            editArea.selectedRange = range
            _ = editArea.becomeFirstResponder()
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = note.scrollPosition, index < self.editArea.textStorage.length {
                let layoutManager = self.editArea.layoutManager
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: index)
                let glyphRect = layoutManager.boundingRect(
                    forGlyphRange: NSRange(location: glyphIndex, length: 1),
                    in: self.editArea.textContainer
                )
                
                let targetY = glyphRect.minY + (note.scrollOffset ?? 0)
                let maxY = max(0, self.editArea.contentSize.height - self.editArea.bounds.height)
                let finalY = min(max(0, targetY), maxY)
                
                self.editArea.contentOffset = CGPoint(x: 0, y: finalY)
            } else {
                self.editArea.contentOffset = .zero
            }
            
            self.editArea.isNoteLoading = false
        }
    }
        
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
