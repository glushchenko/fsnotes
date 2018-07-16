//
//  EditTextView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/11/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Down
import Highlightr
import Carbon.HIToolbox

class EditTextView: NSTextView {
    public static var note: Note?
    var isHighlighted: Bool = false
    let storage = Storage.sharedInstance()
    let caretWidth: CGFloat = 2
    
    class UndoInfo: NSObject {
        let text: String
        let replacementRange: NSRange
        
        init(text: String, replacementRange: NSRange) {
            self.text = text
            self.replacementRange = replacementRange
        }
    }
    
    var downView: MarkdownView?
        
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        validateSubmenu(menu)
    }
    
    //MARK: caret width
    
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        var newRect = NSRect(origin: rect.origin, size: rect.size)
        newRect.size.width = self.caretWidth
        
        if let range = getParagraphRange(), range.upperBound != textStorage?.length || (
            range.upperBound == textStorage?.length
            && textStorage?.string.last == "\n"
            && selectedRange().location != textStorage?.length
        ) {
            newRect.size.height = newRect.size.height - CGFloat(UserDefaultsManagement.editorLineSpacing)
        }
        
        let clr = NSColor(red:0.47, green:0.53, blue:0.69, alpha:1.0)
        super.drawInsertionPoint(in: newRect, color: clr, turnedOn: flag)
    }
    
    override func setNeedsDisplay(_ invalidRect: NSRect) {
        var newInvalidRect = NSRect(origin: invalidRect.origin, size: invalidRect.size)
        newInvalidRect.size.width += self.caretWidth - 1
        super.setNeedsDisplay(newInvalidRect)
    }
 
    // MARK: Menu
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let note = EditTextView.note else { return false }
        
        if menuItem.menu?.identifier?.rawValue == "editMenu" {
            validateSubmenu(menuItem.menu!)
        }
        
        if menuItem.menu?.identifier?.rawValue == "formatMenu", let vc = self.getVc(), vc.notesTableView.selectedRow == -1 || !vc.editArea.hasFocus() {
            return false
        }
        
        if note.isRTF() {
            let disableRTF = [
                NSLocalizedString("Header 1", comment: ""),
                NSLocalizedString("Header 2", comment: ""),
                NSLocalizedString("Header 3", comment: ""),
                NSLocalizedString("Header 4", comment: ""),
                NSLocalizedString("Header 5", comment: ""),
                NSLocalizedString("Header 6", comment: ""),
                NSLocalizedString("Link", comment: ""),
                NSLocalizedString("Image", comment: ""),
                NSLocalizedString("Toggle preview", comment: "")
            ]
            
            return !disableRTF.contains(menuItem.title)
        } else {
            let disable = [
                NSLocalizedString("Underline", comment: ""),
                NSLocalizedString("Strikethrough", comment: "")
            ]
            
            return !disable.contains(menuItem.title)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        if UserDefaultsManagement.preview {
            return
        }
        
        super.mouseMoved(with: event)
    }
    
    override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
        
        let nsString = string as NSString
        let chars = nsString.substring(with: charRange)
        if let notes = storage.getBy(startWith: chars) {
            let titles = notes.map{ $0.title }
            return titles
        }
        return nil
    }
    
    @IBAction func editorMenuItem(_ sender: NSMenuItem) {
        if sender.title == NSLocalizedString("Image", comment: "") {
            sender.keyEquivalentModifierMask = [.shift, .command]
        }

        let keyEquivalent = (sender as AnyObject).keyEquivalent.lowercased()
        let dict = [
            "b": kVK_ANSI_B, "i": kVK_ANSI_I, "j": kVK_ANSI_J, "y": kVK_ANSI_Y,
            "u": kVK_ANSI_U, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6] as [String: Int]
        
        if let key = dict[keyEquivalent] {
            let keyCode = UInt16(key)
            guard let modifier = (sender as AnyObject).keyEquivalentModifierMask else { return }
            
            _ = formatShortcut(keyCode: keyCode, modifier: modifier)
        }
    }
    
    @IBAction func togglePreview(_ sender: Any) {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        
        viewController.togglePreview()
    }
    
    override func mouseDown(with event: NSEvent) {
        let viewController = self.window?.contentViewController as! ViewController
        if (!viewController.emptyEditAreaImage.isHidden) {
            viewController.makeNote(SearchTextField())
        }
        super.mouseDown(with: event)
        saveCursorPosition()
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        //return super.performKeyEquivalent(with: event)
        /* Skip command-shift-b conflicted with cmd-b */
        if
            event.modifierFlags.contains(.command)
            && event.modifierFlags.contains(.shift)
            && event.keyCode == kVK_ANSI_B {
            
            return super.performKeyEquivalent(with: event)
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    func getSelectedNote() -> Note? {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let note = viewController.notesTableView.getNoteFromSelectedRow()
        return note
    }
    
    var timer: Timer?
    func fill(note: Note, highlight: Bool = false) {
        guard let storage = textStorage else {
            return
        }
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = true
        
        EditTextView.note = note
        UserDefaultsManagement.lastSelectedURL = note.url
        
        subviews.removeAll()
        
        if let appd = NSApplication.shared.delegate as? AppDelegate,
            let md = appd.mainWindowController {
            md.editorUndoManager = note.undoManager
        }
        
        isEditable = !UserDefaultsManagement.preview
        isRichText = note.isRTF()
        
        typingAttributes.removeAll()
        typingAttributes[.font] = UserDefaultsManagement.noteFont
        
        if (UserDefaultsManagement.preview && !isRichText) {
            let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
            let url = NSURL.fileURL(withPath: path!)
            let bundle = Bundle(url: url)
            
            let markdownString = note.getPrettifiedContent()
            let css = getPreviewStyle()
            
            do {
                guard var imagesStorage = note.project?.url else { return }
                
                if note.type == .TextBundle {
                    imagesStorage = note.url
                }
                
                downView = try? MarkdownView(imagesStorage: imagesStorage, frame: (self.superview?.bounds)!, markdownString: markdownString, css: css, templateBundle: bundle) {
                }
                
                addSubview(downView!)
            }
            return
        }
        
        storage.setAttributedString(note.content)
        
        if !note.isMarkdown()  {
            if note.type == .RichText {
                storage.updateFont()
            }
            
            if note.type == .PlainText {
                font = UserDefaultsManagement.noteFont
            }
            
            textColor = UserDefaultsManagement.fontColor
            
            let range = NSRange(0..<storage.length)
            let processor = NotesTextProcessor(storage: storage, range: range)
            processor.higlightLinks()
        }
        
        if highlight {
            let search = getSearchText()
            let processor = NotesTextProcessor(storage: storage)
            processor.highlightKeyword(search: search)
            isHighlighted = true
        }
        
        if note.isMarkdown() && note.isCached && UserDefaultsManagement.liveImagesPreview {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(0.3), target: self, selector: #selector(loadImages), userInfo: nil, repeats: false)
        }
        
        viewController.titleLabel.stringValue = note.title
        restoreCursorPosition()
        
        applyLeftParagraphStyle()
    }
    
    @objc func loadImages() {
        if let note = self.getSelectedNote(), UserDefaultsManagement.liveImagesPreview {
            let processor = ImagesProcessor(styleApplier: textStorage!, maxWidth: frame.width, note: note)
            processor.load()
        }
    }
    
    func removeHighlight() {
        guard isHighlighted else {
            return
        }
        
        isHighlighted = false
        
        // save cursor position
        let cursorLocation = selectedRanges[0].rangeValue.location
        
        let search = getSearchText()
        let processor = NotesTextProcessor(storage: textStorage)
        processor.highlightKeyword(search: search, remove: true)
        
        // restore cursor
        setSelectedRange(NSRange.init(location: cursorLocation, length: 0))
    }
    
    func clear() {
        textStorage?.setAttributedString(NSAttributedString())
        subviews.removeAll()
        isEditable = false
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        self.window?.title = appDelegate.appTitle
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = false
        viewController.titleLabel.stringValue = "FSNotes"
    }
    
    func formatShortcut(keyCode: UInt16, modifier: NSEvent.ModifierFlags) -> Bool {
        guard
            let mainWindow = NSApplication.shared.windows.first,
            let vc = mainWindow.contentViewController as? ViewController,
            let editArea = vc.editArea,
            let note = getSelectedNote(),
            !UserDefaultsManagement.preview,
            editArea.isEditable else { return false }

        let formatter = TextFormatter(textView: editArea, note: note)
        
        switch keyCode {
        case 11: // cmd-b
            formatter.bold()
            return true
        case 34: // command-shift-i (image) | command-option-i (link) | command-i
            if (note.isMarkdown() && modifier.contains([.command, .option])) { //
                formatter.link()
                return true
            }
        
            formatter.italic()
            return true
        case 32: // cmd-u
            formatter.underline()
            return true
        case 16: // cmd-y
            formatter.strike()
            return true
        case (18...23): // cmd-1/6 (headers 1/6)
            if note.isMarkdown() {
                var string = ""
                for index in [18, 19, 20, 21, 23, 22] {
                    string = string + "#"
                    if Int(keyCode) == index {
                        break
                    }
                }
                
                formatter.header(string)
                return true
            }
            
            return false
        default:
            return false
        }
    }
    
    func getParagraphRange() -> NSRange? {
        guard let mw = NSApplication.shared.windows.first, let c = mw.contentViewController as? ViewController, let editArea = c.editArea, let storage = editArea.textStorage else {
            return nil
        }
        
        let range = editArea.selectedRange()
        let string = storage.string as NSString
        let paragraphRange = string.paragraphRange(for: range)
        
        return paragraphRange
    }
    
    private func getParagraphRange(for location: Int) -> NSRange? {
        guard let mw = NSApplication.shared.windows.first,
            let c = mw.contentViewController as? ViewController,
            let editArea = c.editArea,
            let storage = editArea.textStorage else { return nil }
        
        let string = storage.string as NSString
        let range = NSRange(location: location, length: 0)
        let paragraphRange = string.paragraphRange(for: range)
    
        return paragraphRange
    }
    
    func toggleBoldFont(font: NSFont) -> NSFont {
        guard let family = UserDefaultsManagement.noteFont.familyName else {
            return UserDefaultsManagement.noteFont
        }
        
        var mask = 0
        if (font.isBold) {
            if (font.isItalic) {
                mask = NSFontItalicTrait
            }
        } else {
            if (font.isItalic) {
                mask = NSFontBoldTrait|NSFontItalicTrait
            } else {
                mask = NSFontBoldTrait
            }
        }
        
        return NSFontManager().font(withFamily: family, traits: NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(mask)), weight: 5, size: CGFloat(UserDefaultsManagement.fontSize))!
    }
    
    func toggleItalicFont(font: NSFont) -> NSFont? {
        guard let family = UserDefaultsManagement.noteFont.familyName else {
            return UserDefaultsManagement.noteFont
        }
        
        var mask = 0
        if (font.isItalic) {
            if (font.isBold) {
                mask = NSFontBoldTrait
            }
        } else {
            if (font.isBold) {
                mask = NSFontBoldTrait|NSFontItalicTrait
            } else {
                mask = NSFontItalicTrait
            }
        }
        
        let size = CGFloat(UserDefaultsManagement.fontSize)
        guard let newFont = NSFontManager().font(withFamily: family, traits: NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(mask)), weight: 5, size: size) else {
            return nil
        }
        
        return newFont
    }
    
    override func paste(_ sender: Any?) {
        super.paste(sender)
        
        guard let note = EditTextView.note, note.isMarkdown(), let clipboard = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string), let storage = textStorage else {
            return
        }
        
        let end = (selectedRanges[0] as! NSRange).location
        let start = end - clipboard.count
        let range = NSRange(start..<end)
        
        NotesTextProcessor.fullScan(note: note, storage: storage, range: range)
        note.save(needImageUnLoad: true)
        
        cacheNote(note: note)
        
        if UserDefaultsManagement.liveImagesPreview {
            let processor = ImagesProcessor(styleApplier: storage, range: range, maxWidth: frame.width, note: note)
            processor.load()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        guard let note = EditTextView.note else {
            return
        }
        
        let brackets = [
            "(" : ")",
            "[" : "]",
            "{" : "}",
            "\"" : "\"",
        ]
        if UserDefaultsManagement.autocloseBrackets,
            let openingBracket = event.characters,
            let closingBracket = brackets[openingBracket] {
            if selectedRange().length > 0 {
                let before = NSMakeRange(selectedRange().lowerBound, 0)
                self.insertText(openingBracket, replacementRange: before)
                let after = NSMakeRange(selectedRange().upperBound, 0)
                self.insertText(closingBracket, replacementRange: after)
            }
            else {
                super.keyDown(with: event)
                self.insertText(closingBracket, replacementRange: selectedRange())
                self.moveBackward(self)
            }
            return
        }
        
        if event.keyCode == kVK_Return {
            super.keyDown(with: event)
            
            let formatter = TextFormatter(textView: self, note: note)
            formatter.newLine()
            return
        }
        
        if event.keyCode == kVK_Tab {
            if event.modifierFlags.contains(.shift) {
                let formatter = TextFormatter(textView: self, note: note)
                formatter.unTab()
                saveCursorPosition()
                return
            }
            
            insertTab(nil)
            saveCursorPosition()
            return
        }
        
        if note.type == .PlainText || note.type == .RichText {
            super.keyDown(with: event)
            saveCursorPosition()
            
            let range = getParagraphRange()
            let processor = NotesTextProcessor(storage: textStorage, range: range)
            processor.higlightLinks()
            
            if note.type == .RichText {
                cacheNote(note: note)
            }
            
            return
        }
        
        super.keyDown(with: event)
        saveCursorPosition()
        
        let range = selectedRanges[0] as! NSRange
        guard let storage = textStorage, note.content.length >= range.location + range.length else {
            return
        }
        
        let textChanged = event.keyCode == kVK_Return
        let processor = NotesTextProcessor(note: note, storage: storage, range: range, maxWidth: frame.width)
        processor.scanParagraph(textChanged: textChanged)
        cacheNote(note: note)
        note.unLoadImages()
    }
    
    func saveCursorPosition() {
        guard let note = EditTextView.note, let range = selectedRanges[0] as? NSRange, UserDefaultsManagement.restoreCursorPosition else {
            return
        }
        
        var length = range.lowerBound
        let data = Data(bytes: &length, count: MemoryLayout.size(ofValue: length))
        try? note.url.setExtendedAttribute(data: data, forName: "co.fluder.fsnotes.cursor")
    }
    
    func restoreCursorPosition() {
        guard let storage = textStorage else { return }
        
        var position = storage.length
        
        guard UserDefaultsManagement.restoreCursorPosition else {
            setSelectedRange(NSMakeRange(position, 0))
            return
        }
        
        if let note = EditTextView.note {
            if let data = try? note.url.extendedAttribute(forName: "co.fluder.fsnotes.cursor") {
                position = data.withUnsafeBytes { (ptr: UnsafePointer<Int>) -> Int in
                    return ptr.pointee
                }
            }
        }
        
        if position <= storage.length {
            setSelectedRange(NSMakeRange(position, 0))
        }
        
        scrollToCursor()
    }
    
    func cacheNote(note: Note) {
        guard let storage = self.textStorage else {
            return
        }
        
        note.content = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: NSRange(0..<storage.length)))
    }
    
    func setEditorTextColor(_ color: NSColor) {
        if let note = EditTextView.note, !note.isMarkdown() {
            textColor = color
        }
    }
    
    func getPreviewStyle() -> String {
        var codeStyle = ""
        if let hgPath = Bundle(for: Highlightr.self).path(forResource: UserDefaultsManagement.codeTheme + ".min", ofType: "css") {
            codeStyle = try! String.init(contentsOfFile: hgPath)
        }
        
        guard let familyName = UserDefaultsManagement.noteFont.familyName else {
            return codeStyle
        }
        
        return "body {font: \(UserDefaultsManagement.fontSize)px \(familyName); } code, pre {font: \(UserDefaultsManagement.fontSize)px Source Code Pro;} \(codeStyle)"
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([
            NSPasteboard.PasteboardType(kUTTypeFileURL as String)
        ])
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let board = sender.draggingPasteboard()
        var data: Data
        
        guard let note = getSelectedNote(), let storage = textStorage else { return false }
        
        if let data = board.data(forType: NSPasteboard.PasteboardType.init(rawValue: "attributedText")), let attributedText = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSMutableAttributedString {
            let dropPoint = convert(sender.draggingLocation(), from: nil)
            let caretLocation = characterIndexForInsertion(at: dropPoint)
            
            let filePathKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.path")
            let titleKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.title")
            let positionKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.position")
            
            guard
                let path = attributedText.attribute(filePathKey, at: 0, effectiveRange: nil) as? String,
                let title = attributedText.attribute(titleKey, at: 0, effectiveRange: nil) as? String,
                let position = attributedText.attribute(positionKey, at: 0, effectiveRange: nil) as? Int else { return false }
            
            guard let imageUrl = note.getImageUrl(imageName: path) else { return false }
            let cacheUrl = note.getImageCacheUrl()
            
            let attachment = ImageAttachment(title: title, path: path, url: imageUrl, cache: cacheUrl)
            guard let attachmentText = attachment.getAttributedString() else { return false }

            let locationDiff = position > caretLocation ? caretLocation : caretLocation - 1
            guard locationDiff < storage.length else { return false }
            
            textStorage?.deleteCharacters(in: NSRange(location: position, length: 1))
            textStorage?.replaceCharacters(in: NSRange(location: locationDiff, length: 0), with: attachmentText)
            
            unLoadImages()
            setSelectedRange(NSRange(location: caretLocation, length: 0))
            
            return true
        }
        
        if let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
            urls.count > 0 {
            
            let dropPoint = convert(sender.draggingLocation(), from: nil)
            let caretLocation = characterIndexForInsertion(at: dropPoint)
            
            var result = String()
            unLoadImages()
            
            for url in urls {
                do {
                    data = try Data(contentsOf: url)
                } catch {
                    return false
                }
                
                let processor = ImagesProcessor(styleApplier: storage, maxWidth: frame.width, note: note)
                
                guard let fileName = processor.writeImage(data: data, url: url),
                      let name = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else
                {
                    return false
                }
                
                let affectedRange = NSRange(location: caretLocation, length: 0)
                
                var markup = "![](/i/\(name))"
                if note.type == .TextBundle {
                    markup = "![](assets/\(name))"
                }
                markup += "\n\n"
                result.append(markup)
            }
            
            insertText(result, replacementRange: NSRange(location: caretLocation, length: 0))
       
            if !UserDefaultsManagement.liveImagesPreview {
                NotesTextProcessor.scanBasicSyntax(note: note, storage: textStorage, range: NSRange(0..<storage.length))
                cacheNote(note: note)
            }
            
            loadImages()

            return true
        }
        
        return false
    }
    
    public func unLoadImages() {
        guard let note = getSelectedNote() else { return }
        note.content = NSMutableAttributedString(attributedString:  attributedString())
        note.save(needImageUnLoad: true)
    }
    
    func getSearchText() -> String {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let search = viewController.search.stringValue
        
        return search
    }
    
    @objc func undoEdit(_ object: UndoData) {
        textStorage?.beginEditing()
        textStorage?.replaceCharacters(in: object.range, with: object.string)
        textStorage?.endEditing()
    }
    
    public func scrollToCursor() {
        let cursorRange = NSMakeRange(self.selectedRange().location, 0)
        scrollRangeToVisible(cursorRange)
    }
    
    public func hasFocus() -> Bool {
        if let fr = self.window?.firstResponder, fr.isKind(of: EditTextView.self) {
            return true
        }
        
        return false
    }
    
    private func getVc() -> ViewController? {
        if let viewController = NSApplication.shared.windows.first?.contentViewController as? ViewController {
            return viewController
        }
        
        return nil
    }
    
    @IBAction func shiftLeft(_ sender: Any) {
        guard let f = self.getTextFormatter() else { return }
        
        f.unTab()
    }
    
    @IBAction func shiftRight(_ sender: Any) {
        guard let f = self.getTextFormatter() else { return }
        
        f.tab()
    }
    
    @IBAction func toggleTodo(_ sender: Any) {
        guard let f = self.getTextFormatter() else { return }
        
        f.toggleTodo()
    }
    
    @IBAction func insertMarkdownImage(_ sender: Any) {
        guard let f = self.getTextFormatter() else { return }
        
        f.image()
    }
    
    private func getTextFormatter() -> TextFormatter? {
        guard let note = EditTextView.note else { return nil }
        
        return TextFormatter(textView: self, note: note)
    }
    
    private func hasAttachmentAt(location: Int) -> Bool {
        guard let length = textStorage?.length, length > location else { return false }

        return (textStorage?.attribute(NSAttributedStringKey.attachment, at: location, effectiveRange: nil) != nil)
    }
    
    private func validateSubmenu(_ menu: NSMenu) {
        let sg = menu.item(withTitle: NSLocalizedString("Spelling and Grammar", comment: ""))?.submenu
        let s = menu.item(withTitle: NSLocalizedString("Substitutions", comment: ""))?.submenu
        
        sg?.item(withTitle: NSLocalizedString("Check Spelling While Typing", comment: ""))?.state = self.isContinuousSpellCheckingEnabled ? .on : .off
        sg?.item(withTitle: NSLocalizedString("Check Grammar With Spelling", comment: ""))?.state = self.isGrammarCheckingEnabled ? .on : .off
        sg?.item(withTitle: NSLocalizedString("Correct Spelling Automatically", comment: ""))?.state = self.isAutomaticSpellingCorrectionEnabled ? .on : .off
        
        s?.item(withTitle: NSLocalizedString("Smart Copy/Paste", comment: ""))?.state = self.smartInsertDeleteEnabled ? .on : .off
        s?.item(withTitle: NSLocalizedString("Smart Quotes", comment: ""))?.state = self.isAutomaticQuoteSubstitutionEnabled ? .on : .off
        
        s?.item(withTitle: NSLocalizedString("Smart Dashes", comment: ""))?.state = self.isAutomaticDashSubstitutionEnabled ? .on : .off
        s?.item(withTitle: NSLocalizedString("Smart Links", comment: ""))?.state = self.isAutomaticLinkDetectionEnabled  ? .on : .off
        s?.item(withTitle: NSLocalizedString("Text Replacement", comment: ""))?.state = self.isAutomaticTextReplacementEnabled   ? .on : .off
        s?.item(withTitle: NSLocalizedString("Data Detectors", comment: ""))?.state = self.isAutomaticDataDetectionEnabled ? .on : .off
    }
        
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let selected = attributedSubstring(forProposedRange: selectedRange(), actualRange: nil) else { return .generic }
        
        let attributedString = NSMutableAttributedString(attributedString: selected)
        let positionKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.position")
        attributedString.addAttribute(positionKey, value: selectedRange().location, range: NSRange(0..<1))
        
        let data = NSKeyedArchiver.archivedData(withRootObject: attributedString)
        let type = NSPasteboard.PasteboardType.init(rawValue: "attributedText")
        let board = sender.draggingPasteboard()
        board.setData(data, forType: type)
        
        return .copy
    }
    
    public func applyLeftParagraphStyle() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        paragraphStyle.alignment = .left
        typingAttributes[.paragraphStyle] = paragraphStyle
        defaultParagraphStyle = paragraphStyle
        textStorage?.updateParagraphStyle()
    }
    
    override func clicked(onLink link: Any, at charIndex: Int) {
        let range = NSRange(location: charIndex, length: 1)
        
        let char = attributedSubstring(forProposedRange: range, actualRange: nil)
        if char?.attribute(.attachment, at: 0, effectiveRange: nil) == nil {
            if let url = URL(string: link as! String) {
                NSWorkspace.shared.open(url)
            }
            
            return
        }
        
        let window = NSApp.windows[0]
        let titleKey = NSAttributedStringKey(rawValue: "co.fluder.fsnotes.image.title")
        
        guard let vc = window.contentViewController as? ViewController else { return }

        vc.alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
        field.placeholderString = "All Hail the Crimson King"
        
        if let title = char?.attribute(titleKey, at: 0, effectiveRange: nil) as? String {
            field.stringValue = title
        }
        
        vc.alert?.messageText = NSLocalizedString("Image title", comment: "Edit area")
        vc.alert?.informativeText = NSLocalizedString("Please enter image title:", comment: "Edit area")
        vc.alert?.accessoryView = field
        vc.alert?.alertStyle = .informational
        vc.alert?.addButton(withTitle: "OK")
        vc.alert?.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                self.textStorage?.addAttribute(titleKey, value: field.stringValue, range: range)
                
                if let note = vc.notesTableView.getSelectedNote() {
                    note.content = NSMutableAttributedString(attributedString: self.attributedString())
                    note.save(needImageUnLoad: true)
                }
            }
        }
        
        field.becomeFirstResponder()
    }
    
    
    
}
