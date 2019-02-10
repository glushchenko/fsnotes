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
import FSNotesCore_macOS

class EditTextView: NSTextView, NSTextFinderClient {
    public static var note: Note?
    public static var isBusyProcessing: Bool = false

    public var viewDelegate: ViewController?
    
    var isHighlighted: Bool = false
    let storage = Storage.sharedInstance()
    let caretWidth: CGFloat = 2
    var downView: MarkdownView?
    var timer: Timer?

    public static var imagesLoaderQueue = OperationQueue.init()
    
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

    override func updateInsertionPointStateAndRestartTimer(_ restartFlag: Bool) {
        super.updateInsertionPointStateAndRestartTimer(true)
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
                NSLocalizedString("Toggle preview", comment: ""),
                NSLocalizedString("Code Block", comment: "")
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
    
    // MARK: Overrides
    
    override func toggleContinuousSpellChecking(_ sender: Any?) {
        if let menu = sender as? NSMenuItem {
            UserDefaultsManagement.continuousSpellChecking = (menu.state == .off)
        }
        super.toggleContinuousSpellChecking(sender)
    }
    
    override func toggleGrammarChecking(_ sender: Any?) {
        if let menu = sender as? NSMenuItem {
            UserDefaultsManagement.grammarChecking = (menu.state == .off)
        }
        super.toggleGrammarChecking(sender)
    }
    
    override func toggleAutomaticSpellingCorrection(_ sender: Any?) {
        if let menu = sender as? NSMenuItem {
            UserDefaultsManagement.automaticSpellingCorrection = (menu.state == .off)
        }
        super.toggleAutomaticSpellingCorrection(sender)
    }
    
    override func toggleSmartInsertDelete(_ sender: Any?) {
        if let menu = sender as? NSMenuItem {
            UserDefaultsManagement.smartInsertDelete = (menu.state == .off)
        }
        super.toggleSmartInsertDelete(sender)
    }
    
    override func toggleAutomaticQuoteSubstitution(_ sender: Any?) {
        if let menu = sender as? NSMenuItem {
            UserDefaultsManagement.automaticQuoteSubstitution = (menu.state == .off)
        }
        super.toggleAutomaticQuoteSubstitution(sender)
    }
    
    override func toggleAutomaticDataDetection(_ sender: Any?) {
        if let menu = sender as? NSMenuItem {
            UserDefaultsManagement.automaticDataDetection = (menu.state == .off)
        }
        super.toggleAutomaticDataDetection(sender)
    }
    
    override func toggleAutomaticLinkDetection(_ sender: Any?) {
        if let menu = sender as? NSMenuItem {
            UserDefaultsManagement.automaticLinkDetection = (menu.state == .off)
        }
        super.toggleAutomaticLinkDetection(sender)
    }
    
    override func toggleAutomaticTextReplacement(_ sender: Any?) {
        if let menu = sender as? NSMenuItem {
            UserDefaultsManagement.automaticTextReplacement = (menu.state == .off)
        }
        super.toggleAutomaticTextReplacement(sender)
    }
    
    override func toggleAutomaticDashSubstitution(_ sender: Any?) {
        if let menu = sender as? NSMenuItem {
            UserDefaultsManagement.automaticDashSubstitution = (menu.state == .off)
        }
        super.toggleAutomaticDashSubstitution(sender)
    }

    override func mouseDown(with event: NSEvent) {
        let viewController = self.window?.contentViewController as! ViewController
        if (!viewController.emptyEditAreaImage.isHidden) {
            viewController.makeNote(viewController.search)
        }

        guard let container = self.textContainer, let manager = self.layoutManager else { return }

        let point = self.convert(event.locationInWindow, from: nil)
        let properPoint = NSPoint(x: point.x - textContainerInset.width, y: point.y)

        let index = manager.characterIndex(for: properPoint, in: container, fractionOfDistanceBetweenInsertionPoints: nil)

        let glyphRect = manager.boundingRect(forGlyphRange: NSRange(location: index, length: 1), in: container)

        if glyphRect.contains(properPoint), isTodo(index) {
            guard let f = self.getTextFormatter() else { return }
            f.toggleTodo(index)
            
            DispatchQueue.main.async {
                NSCursor.pointingHand.set()
            }
            return
        }
        
        super.mouseDown(with: event)
        saveCursorPosition()
        
        if !UserDefaultsManagement.preview {
            self.isEditable = true
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let viewController = self.window?.contentViewController as! ViewController
        if (!viewController.emptyEditAreaImage.isHidden) {
            NSCursor.pointingHand.set()
            return
        }

        let point = self.convert(event.locationInWindow, from: nil)
        let properPoint = NSPoint(x: point.x - textContainerInset.width, y: point.y)

        guard let container = self.textContainer, let manager = self.layoutManager else { return }

        let index = manager.characterIndex(for: properPoint, in: container, fractionOfDistanceBetweenInsertionPoints: nil)

        let glyphRect = manager.boundingRect(forGlyphRange: NSRange(location: index, length: 1), in: container)
        
        if glyphRect.contains(properPoint), self.isTodo(index) {
            NSCursor.pointingHand.set()
            return
        }

        if glyphRect.contains(properPoint), ((textStorage?.attribute(.link, at: index, effectiveRange: nil)) != nil) {
            NSCursor.pointingHand.set()
            return
        }
        
        if UserDefaultsManagement.preview {
            return
        }
        
        super.mouseMoved(with: event)
    }
    
    public func isTodo(_ location: Int) -> Bool {
        guard let storage = self.textStorage else { return false }
        
        let range = (storage.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
        let string = storage.attributedSubstring(from: range).string as NSString

        if storage.attribute(.todo, at: location, effectiveRange: nil) != nil {
            return true
        }

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
    
    override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
        
        let nsString = string as NSString
        let chars = nsString.substring(with: charRange)
        if let notes = storage.getBy(startWith: chars) {
            let titles = notes.map{ $0.title }
            return titles
        }
        return nil
    }

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        get {
            return [NSPasteboard.PasteboardType.rtfd, NSPasteboard.PasteboardType.string]
        }
    }
    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {

        guard let storage = textStorage else { return false }

        let range = selectedRange()
        let attributedString = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: range))

        if type == .string {
            let plainText = attributedString.unLoadImages().unLoadCheckboxes().string

            pboard.setString(plainText, forType: .string)
            return true
        }

        if type == .rtfd {
            let richString = attributedString.unLoadCheckboxes()
            if let rtfd = try? richString.data(from: NSMakeRange(0, richString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtfd]) {
                pboard.setData(rtfd, forType: NSPasteboard.PasteboardType.rtfd)
                return true
            }
        }

        return false
    }

    // Copy empty string
    override func copy(_ sender: Any?) {
        if self.selectedRange.length == 0, let paragraphRange = self.getParagraphRange(), let paragraph = attributedSubstring(forProposedRange: paragraphRange, actualRange: nil) {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(paragraph.string.trim().removeLastNewLine(), forType: NSPasteboard.PasteboardType.string)
            return
        }

        super.copy(sender)
    }

    override func paste(_ sender: Any?) {
        guard let note = EditTextView.note, let storage = textStorage else { return }

        guard note.isMarkdown() else {
            super.paste(sender)

            fillPlainAndRTFStyle(note: note, saveTyping: false)
            return
        }

        if let clipboard = NSPasteboard.general.data(forType: .rtfd) {
            let currentRange = selectedRange()

            if let string = NSAttributedString(rtfd: clipboard, documentAttributes: nil) {
                self.insertText(string, replacementRange: currentRange)
            }

            let range = NSRange(currentRange.location..<storage.length)
            NotesTextProcessor.fullScan(note: note, storage: storage, range: range)
            note.save()

            saveTextStorageContent(to: note)

            // Set image size and .link after storage full scan (cleaned)
            storage.sizeAttachmentImages()

            return
        }

        if pasteImageFromClipboard(in: note) {
            return
        }

        if let clipboard = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string) {
            let currentRange = selectedRange()

            self.insertText(clipboard, replacementRange: currentRange)

            let range = NSRange(currentRange.location..<storage.length)
            NotesTextProcessor.fullScan(note: note, storage: storage, range: range)
            note.save()

            saveTextStorageContent(to: note)

            if UserDefaultsManagement.liveImagesPreview {
                let processor = ImagesProcessor(styleApplier: storage, range: range, note: note, textView: self)
                processor.load()
            }

            return
        }
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
    
    func getSelectedNote() -> Note? {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let note = viewController.notesTableView.getSelectedNote()
        return note
    }

    func fill(note: Note, highlight: Bool = false, saveTyping: Bool = false) {
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = true

        EditTextView.note = note
        UserDefaultsManagement.lastSelectedURL = note.url
        
        downView?.removeFromSuperview()

        viewController.updateTitle(newTitle: note.title)

        if let appd = NSApplication.shared.delegate as? AppDelegate,
            let md = appd.mainWindowController {
            md.editorUndoManager = note.undoManager
        }

        isEditable = !(UserDefaultsManagement.preview && note.isMarkdown())

        if !saveTyping {
            typingAttributes.removeAll()
            typingAttributes[.font] = UserDefaultsManagement.noteFont
        }

        if (UserDefaultsManagement.preview && note.isMarkdown()) {
            // Removes scroll for long notes
            
            EditTextView.note = nil
            textStorage?.setAttributedString(NSAttributedString())
            EditTextView.note = note

            let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
            let url = NSURL.fileURL(withPath: path!)
            let bundle = Bundle(url: url)

            let markdownString = note.getPrettifiedContent()
            let css = getPreviewStyle()

            do {
                var imagesStorage = note.project.url

                if note.type == .TextBundle {
                    imagesStorage = note.url
                }

                downView = try? MarkdownView(imagesStorage: imagesStorage, frame: (viewController.editAreaScroll.bounds), markdownString: markdownString, css: css, templateBundle: bundle, didLoadSuccessfully: {
                    viewController.editAreaScroll.addSubview(self.downView!)
                })
            }
            return
        }

        guard let storage = textStorage else { return }
        storage.setAttributedString(note.content)

        if !note.isMarkdown()  {
            fillPlainAndRTFStyle(note: note, saveTyping: saveTyping)
        }
        
        if highlight {
            let search = getSearchText()
            let processor = NotesTextProcessor(storage: storage)
            processor.highlightKeyword(search: search)
            isHighlighted = true
        }
        
        if note.isMarkdown() {
            EditTextView.isBusyProcessing = true
            textStorage?.replaceCheckboxes()

            if UserDefaultsManagement.liveImagesPreview {
                EditTextView.imagesLoaderQueue.cancelAllOperations()
                loadImages()
            }
            
            EditTextView.isBusyProcessing = false
        }

        restoreCursorPosition()
        applyLeftParagraphStyle()

        if UserDefaultsManagement.appearanceType == AppearanceType.Custom {
            backgroundColor = UserDefaultsManagement.bgColor
        }
    }

    private func fillPlainAndRTFStyle(note: Note, saveTyping: Bool) {
        guard let storage = textStorage else { return }

        if note.type == .RichText && !saveTyping {
            storage.updateFont()
        }

        if note.type == .PlainText {
            font = UserDefaultsManagement.noteFont
        }

        setTextColor()

        let range = NSRange(0..<storage.length)
        let processor = NotesTextProcessor(storage: storage, range: range)
        processor.higlightLinks()
    }

    private func setTextColor() {
        if UserDefaultsManagement.appearanceType != AppearanceType.Custom, #available(OSX 10.13, *) {
            textColor = NSColor.init(named: NSColor.Name(rawValue: "mainText"))
        } else {
            textColor = UserDefaultsManagement.fontColor
        }
    }

    @objc func loadImages() {
        if let note = self.getSelectedNote(), UserDefaultsManagement.liveImagesPreview {
            let processor = ImagesProcessor(styleApplier: textStorage!, note: note)
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
        downView?.removeFromSuperview()
        isEditable = false
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        self.window?.title = appDelegate.appTitle
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = false
        viewController.updateTitle(newTitle: nil)
        
        EditTextView.note = nil
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
        guard let mw = NSApplication.shared.windows.first,
            let c = mw.contentViewController as? ViewController,
            let editArea = c.editArea,
            let storage = editArea.textStorage
        else {
            return nil
        }
        
        let range = editArea.selectedRange()
        return storage.mutableString.paragraphRange(for: range)
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

    override func keyDown(with event: NSEvent) {
        guard let storage = self.textStorage else { return }

        guard !(
            event.modifierFlags.contains(.shift) &&
            [
                kVK_UpArrow,
                kVK_DownArrow,
                kVK_LeftArrow,
                kVK_RightArrow
            ].contains(Int(event.keyCode))
        ) else {
            super.keyDown(with: event)
            return
        }
        
        guard let note = EditTextView.note else {
            return
        }
        
        let brackets = [
            "(" : ")",
            "[" : "]",
            "{" : "}",
            "\"" : "\"",
        ]
        
        let sRange = selectedRange()
        
        if UserDefaultsManagement.autocloseBrackets,
            let openingBracket = event.characters,
            let closingBracket = brackets[openingBracket] {
            if selectedRange().length > 0 {
                let before = NSMakeRange(selectedRange().lowerBound, 0)
                self.insertText(self.applyStyle(openingBracket), replacementRange: before)
                let after = NSMakeRange(selectedRange().upperBound, 0)
                self.insertText(self.applyStyle(closingBracket), replacementRange: after)
            } else {
                super.keyDown(with: event)
                self.insertText(self.applyStyle(closingBracket), replacementRange: selectedRange())
                
                let paragraphRange = (storage.string as NSString).paragraphRange(for: sRange)
                if self.isCodeBlock(range: paragraphRange) && note.isMarkdown() {
                    let attributes = getCodeBlockAttributes()
                    storage.addAttributes(attributes, range: NSRange(location: sRange.location, length: 1))
                }
                
                self.moveBackward(self)
            }
            return
        }

        if event.keyCode == kVK_Tab {
            if event.modifierFlags.contains(.shift) {
                let formatter = TextFormatter(textView: self, note: note)
                formatter.unTab()
                saveCursorPosition()
                return
            }
        }
        
        if note.type == .PlainText || note.type == .RichText {
            super.keyDown(with: event)
            saveCursorPosition()
            
            let range = getParagraphRange()
            let processor = NotesTextProcessor(storage: textStorage, range: range)
            processor.higlightLinks()
            
            if note.type == .RichText {
                saveTextStorageContent(to: note)
            }
            
            return
        }
        
        super.keyDown(with: event)
        saveCursorPosition()
    }

    var shouldChange = true
    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard shouldChange, let note = EditTextView.note else {
            breakUndoCoalescing()
            return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        }

        typingAttributes.removeValue(forKey: .todo)

        // New line
        if replacementString == "\n" {
            shouldChange = false
            let formatter = TextFormatter(textView: self, note: note, shouldScanMarkdown: false)
            formatter.newLine()
            shouldChange = true
            return false
        }

        // Tab
        if replacementString == "\t" {
            shouldChange = false
            let formatter = TextFormatter(textView: self, note: note, shouldScanMarkdown: false)
            formatter.tabKey()
            shouldChange = true
            return false
        }


        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    public func isCodeBlock(paragraph: String) -> Bool {
        if paragraph.starts(with: "\t") || paragraph.starts(with: "    ") {
            guard TextFormatter.getAutocompleteCharsMatch(string: string) == nil && TextFormatter.getAutocompleteDigitsMatch(string: string) == nil else {
                return false
            }

            return true
        }

        return false
    }
    
    public func applyStyle(_ text: String) -> NSMutableAttributedString {
        let attributedText = NSMutableAttributedString(string: text)

        guard attributedText.length > 0, let note = EditTextView.note, note.isMarkdown() else { return attributedText }
        
        if let paragraphRange = getParagraphRange(), self.isCodeBlock(range: paragraphRange) {
            let range = NSRange(0..<text.count)
            attributedText.addAttributes(getCodeBlockAttributes(), range: range)
        }
        
        return attributedText
    }
    
    public func getCodeBlockAttributes() -> [NSAttributedStringKey : Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        
        var attributes: [NSAttributedStringKey : Any] = [
            .backgroundColor: NotesTextProcessor.codeBackground,
            .paragraphStyle: paragraphStyle
        ]
        
        if let font = NotesTextProcessor.codeFont {
            attributes[.font] = font
        }
        
        return attributes
    }
    
    private func isCodeBlock(range: NSRange) -> Bool {
        guard let storage = textStorage else { return false }
        
        let string = storage.attributedSubstring(from: range).string
        
        if string.starts(with: "\t") || string.starts(with: "    ") {
            return true
        }
        
        if nil != NotesTextProcessor.getFencedCodeBlockRange(paragraphRange: range, string: storage) {
            return true
        }
        
        return false
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

        guard UserDefaultsManagement.restoreCursorPosition else {
            setSelectedRange(NSMakeRange(0, 0))
            return
        }

        var position = storage.length
        
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
    
    func saveTextStorageContent(to note: Note) {
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

        EditTextView.imagesLoaderQueue.maxConcurrentOperationCount = 2
        EditTextView.imagesLoaderQueue.qualityOfService = .userInteractive
    }

    override var textContainerOrigin: NSPoint {
        let origin = super.textContainerOrigin
        return NSPoint(x: origin.x, y: origin.y - 10)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let board = sender.draggingPasteboard()
        let range = selectedRange
        var data: Data

        guard let note = getSelectedNote(), let storage = textStorage else { return false }

        if let data = board.data(forType: .rtfd),
            let text = NSAttributedString(rtfd: data, documentAttributes: nil),
            text.length > 0,
            range.length > 0
        {
            insertText("", replacementRange: range)

            let dropPoint = convert(sender.draggingLocation(), from: nil)
            let caretLocation = characterIndexForInsertion(at: dropPoint)

            let mutable = NSMutableAttributedString(attributedString: text)
            mutable.loadCheckboxes()

            insertText(mutable, replacementRange: NSRange(location: caretLocation, length: 0))
            storage.sizeAttachmentImages()

            DispatchQueue.main.async {
                self.setSelectedRange(NSRange(location: caretLocation, length: mutable.length))
            }
            
            return true
        }

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

            let locationDiff = position > caretLocation ? caretLocation : caretLocation - 1
            let attachment = ImageAttachment(title: title, path: path, url: imageUrl, cache: cacheUrl, invalidateRange: NSRange(location: locationDiff, length: 1))
            
            guard let attachmentText = attachment.getAttributedString() else { return false }
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
            var offset = 0

            unLoadImages()
            
            for url in urls {
                do {
                    data = try Data(contentsOf: url)
                } catch {
                    return false
                }
                
                guard let fileName = ImagesProcessor.writeImage(data: data, url: url, note: note),
                      let name = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else
                {
                    return false
                }

                var imagePath = "/i/\(name)"
                if note.type == .TextBundle {
                    imagePath = "assets/\(name)"
                }

                guard let url = note.getImageUrl(imageName: imagePath) else { return false }

                let insertRange = NSRange(location: caretLocation + offset, length: 0)
                let invalidateRange = NSRange(location: caretLocation + offset, length: 1)

                let attachment = ImageAttachment(title: "", path: imagePath, url: url, cache: nil, invalidateRange: invalidateRange, note: note)

                if let string = attachment.getAttributedString() {
                    insertText(string, replacementRange: insertRange)
                    insertNewline(nil)
                    insertNewline(nil)

                    offset += 3
                }
            }

            if !UserDefaultsManagement.liveImagesPreview {
                NotesTextProcessor.scanBasicSyntax(note: note, storage: textStorage, range: NSRange(0..<storage.length))
                saveTextStorageContent(to: note)
            }

            applyLeftParagraphStyle()
            self.viewDelegate?.notesTableView.reloadRow(note: note)

            return true
        }
        
        return false
    }
    
    public func unLoadImages() {
        guard let note = getSelectedNote() else { return }
        note.content = NSMutableAttributedString(attributedString:  attributedString())
        note.save()
    }
    
    func getSearchText() -> String {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let search = viewController.search.stringValue

        if let editor = viewController.search.currentEditor(), editor.selectedRange.length > 0 {
            return (search as NSString).substring(with: NSRange(0..<editor.selectedRange.location))
        }
        
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
        guard let note = EditTextView.note else { return }

        if !UserDefaultsManagement.liveImagesPreview {
            guard let f = self.getTextFormatter() else { return }
            f.image()

            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = true
        panel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                let urls = panel.urls

                for url in urls {
                    if self.saveImageUrl(url: url, in: note) {
                        self.insertNewline(nil)
                    }
                }
            } else {
                exit(EXIT_SUCCESS)
            }
        }
    }

    @IBAction func insertCodeBlock(_ sender: NSButton) {
        let currentRange = selectedRange()
        insertText("```\n\n```\n", replacementRange: currentRange)
        setSelectedRange(NSRange(location: currentRange.location + 4, length: 0))
    }
    
    private func getTextFormatter() -> TextFormatter? {
        guard let note = EditTextView.note else { return nil }
        
        return TextFormatter(textView: self, note: note)
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
            super.clicked(onLink: link, at: charIndex)
            return
        }
        
        if !UserDefaultsManagement.liveImagesPreview {
            let url = URL(fileURLWithPath: link as! String)
            NSWorkspace.shared.open(url)
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
                    note.save()
                }
            }
            
            
            vc.alert = nil
        }
        
        field.becomeFirstResponder()
    }

    override func viewDidChangeEffectiveAppearance() {
        self.storage.fullCacheReset()

        guard let note = EditTextView.note else { return }
        
        UserDataService.instance.isDark = effectiveAppearance.isDark
        UserDefaultsManagement.codeTheme = effectiveAppearance.isDark ? "monokai-sublime" : "atom-one-light"

        NotesTextProcessor.hl = nil
        NotesTextProcessor.fullScan(note: note)

        let funcName = effectiveAppearance.isDark ? "switchToDarkMode" : "switchToLightMode"
        let switchScript = "if (typeof(\(funcName)) == 'function') { \(funcName)(); }"

        downView?.evaluateJavaScript(switchScript)

        // TODO: implement code block live theme changer
        viewDelegate?.refillEditArea()
    }

    private func pasteImageFromClipboard(in note: Note) -> Bool {
        if let url = NSURL(from: NSPasteboard.general) {
            return saveImageUrl(url: url as URL, in: note)
        }

        if let clipboard = NSPasteboard.general.data(forType: .tiff), let image = NSImage(data: clipboard), let jpgData = image.jpgData {
            saveImageClipboard(data: jpgData, note: note)
            note.save()
            saveTextStorageContent(to: note)
            textStorage?.sizeAttachmentImages()
            return true
        }

        return false
    }

    private func saveImageUrl(url: URL, in note: Note) -> Bool {
        if let data = try? Data(contentsOf: url), let _ = NSImage(data: data) {

            var ext = "jpg"
            if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                let uti = CGImageSourceGetType(source)

                if let fileExtension = (uti as String?)?.utiFileExtension {
                    ext = fileExtension
                }
            }

            saveImageClipboard(data: data, note: note, ext: ext)
            note.save()
            saveTextStorageContent(to: note)
            textStorage?.sizeAttachmentImages()

            return true
        }

        return false
    }

    private func saveImageClipboard(data: Data, note: Note, ext: String? = nil) {
        if let string = ImagesProcessor.writeImage(data: data, note: note, ext: ext) {
            let path = note.getMdImagePath(name: string)
            if let imageUrl = note.getImageUrl(imageName: path) {
                let range = NSRange(location: selectedRange.location, length: 1)
                let attachment = ImageAttachment(title: "", path: path, url: imageUrl, cache: nil, invalidateRange: range, note: note)

                if let attributedString = attachment.getAttributedString() {
                    let newLineImage = NSMutableAttributedString(attributedString: attributedString)
                    newLineImage.append(NSAttributedString(string: "\n"))

                    self.insertText(newLineImage, replacementRange: selectedRange())
                    applyLeftParagraphStyle()

                    return
                }
            }
        }
    }

    public func updateTextContainerInset() {
        let lineWidth = UserDefaultsManagement.lineWidth
        let width = frame.width

        if lineWidth == 1000 {
            textContainerInset.width = 5
            return
        }

        guard Float(width) > lineWidth else {
            textContainerInset.width = 5
            return
        }

        let inset = (Float(width) - lineWidth) / 2
        
        textContainerInset.width = CGFloat(inset)
    }
}
