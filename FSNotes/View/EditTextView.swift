//
//  EditTextView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/11/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Carbon.HIToolbox

class EditTextView: NSTextView, NSTextFinderClient, NSSharingServicePickerDelegate {
    
    public var editorViewController: EditorViewController?
    public var textStorageProcessor: TextStorageProcessor?
    public var note: Note?
    public var viewDelegate: ViewController?
    
    let storage = Storage.shared()
    let caretWidth: CGFloat = 2
    var downView: MPreviewView?
    
    public var timer: Timer?
    public var tagsTimer: Timer?
    public var markdownView: MPreviewView?
    public var isLastEdited: Bool = false
    
    @IBOutlet weak var previewMathJax: NSMenuItem!

    public var imagesLoaderQueue = OperationQueue.init()
    public var attributesCachingQueue = OperationQueue.init()
    
    private var preview = false
    
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        validateSubmenu(menu)
    }
    
    override func becomeFirstResponder() -> Bool {        
        if let note = self.note {
            if note.container == .encryptedTextPack {
                return false
            }

            textStorage?.removeHighlight()
        }
        
        return super.becomeFirstResponder()
    }

    //MARK: caret width

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard UserDefaultsManagement.inlineTags else { return }

        if #available(OSX 10.16, *) {
            guard let textStorage = self.textStorage,
                  let layoutManager = self.layoutManager
            else { return }

            let fullRange = NSRange(location: 0, length: textStorage.length)

            attributedString().enumerateAttributes(in: fullRange, options: .reverse) { attributes, range, _ in
                guard attributes.index(forKey: .tag) != nil,
                      let font = attributes[.font] as? NSFont
                else { return }

                let tag = attributedString().attributedSubstring(from: range).string
                let tagAttributes = attributedString().attributes(at: range.location, effectiveRange: nil)

                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                
                let ascent = font.ascender
                let descent = abs(font.descender)
                let fontHeight = ascent + descent

                layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, usedRect, textContainer, lineGlyphRange, stop in

                    let intersectionRange = NSIntersectionRange(glyphRange, lineGlyphRange)
                    guard intersectionRange.length > 0 else { return }
                    
                    var fragmentRect = layoutManager.boundingRect(forGlyphRange: intersectionRange, in: textContainer)
                    
                    fragmentRect.origin.x += self.textContainerOrigin.x
                    fragmentRect.origin.y += self.textContainerOrigin.y
                    fragmentRect = self.convertToLayer(fragmentRect)
                    fragmentRect = fragmentRect.integral

                    let verticalInset = max(0, (fragmentRect.height - fontHeight) / 2)
                    var tagRect = NSRect(
                        x: fragmentRect.minX,
                        y: fragmentRect.minY + verticalInset,
                        width: fragmentRect.width - 3,
                        height: fontHeight
                    )

                    let oneCharSize = ("A" as NSString).size(withAttributes: tagAttributes)
                    tagRect.size.width += oneCharSize.width * 0.25
                    tagRect = tagRect.integral

                    NSGraphicsContext.saveGraphicsState()
                    let path = NSBezierPath(roundedRect: tagRect, xRadius: 3, yRadius: 3)
                    NSColor.tagColor.setFill()
                    path.fill()

                    let fragmentCharRange = layoutManager.characterRange(forGlyphRange: intersectionRange, actualGlyphRange: nil)
                    let fragmentText = (tag as NSString).substring(with: NSRange(
                        location: fragmentCharRange.location - range.location,
                        length: fragmentCharRange.length
                    ))

                    var drawAttrs = tagAttributes
                    drawAttrs[.font] = font
                    drawAttrs[.foregroundColor] = NSColor.white
                    drawAttrs.removeValue(forKey: .link)
                    drawAttrs.removeValue(forKey: .baselineOffset)

                    let baselineOrigin = NSPoint(x: tagRect.minX, y: tagRect.minY + descent - 3)

                    (fragmentText as NSString).draw(at: baselineOrigin, withAttributes: drawAttrs)

                    NSGraphicsContext.restoreGraphicsState()
                }
            }
        }
    }

    public func initTextStorage() {
        let processor = TextStorageProcessor()
        processor.editor = self
        
        textStorageProcessor = processor
        textStorage?.delegate = processor

        guard let textStorage = self.textStorage,
              let oldLayoutManager = self.layoutManager,
              let textContainer = self.textContainer else { return }
        
        textStorage.removeLayoutManager(oldLayoutManager)

        let customLayoutManager = LayoutManager()
        customLayoutManager.addTextContainer(textContainer)
        customLayoutManager.delegate = customLayoutManager
        
        customLayoutManager.processor = processor
        
        textStorage.addLayoutManager(customLayoutManager)
    }
    
    public func configure() {
        DispatchQueue.main.async {
            self.updateTextContainerInset()
        }
            
        attributesCachingQueue.qualityOfService = .background
        textContainerInset.height = 10
        isEditable = false

        layoutManager?.allowsNonContiguousLayout = UserDefaultsManagement.nonContiguousLayout

        if #available(OSX 10.13, *) {} else {
            backgroundColor = UserDefaultsManagement.bgColor
        }

        layoutManager?.defaultAttachmentScaling = .scaleProportionallyDown
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        defaultParagraphStyle = paragraphStyle
        typingAttributes[.paragraphStyle] = paragraphStyle
        
        font = UserDefaultsManagement.noteFont
    }

    public func invalidateLayout() {
        if let length = self.textStorage?.length {
            self.textStorage?.layoutManagers.first?.invalidateLayout(forCharacterRange: NSRange(location: 0, length: length), actualCharacterRange: nil)
        }
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        return []
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        var newRect = rect
        newRect.size.width = caretWidth
        
        // Fixes last line height
        
        if let textStorage = self.textStorage,
           let layoutManager = self.layoutManager as? LayoutManager {
            let insertionPoint = self.selectedRange().location
            
            if insertionPoint == textStorage.length, insertionPoint > 0 {
                let lastIndex = insertionPoint - 1
                let attributes = textStorage.attributes(at: lastIndex, effectiveRange: nil)
                
                let isNewline: Bool = {
                    let ns = textStorage.string as NSString
                    return ns.character(at: lastIndex) == 0x0A // '\n'
                }()

                let fontToUse: NSFont
                if !isNewline, let font = attributes[.font] as? NSFont {
                    fontToUse = font
                } else {
                    fontToUse = UserDefaultsManagement.noteFont
                }
                
                newRect.size.height = layoutManager.lineHeight(for: fontToUse)
            }
        }
        
        let clr = NSColor(red: 0.47, green: 0.53, blue: 0.69, alpha: 1.0)
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
        menuItem.isHidden = false

        if menuItem.menu?.identifier?.rawValue == "editMenu" {
            validateSubmenu(menuItem.menu!)
        }
        
        if menuItem.menu?.identifier?.rawValue == "formatMenu", !hasFocus() {
            return false
        }

        let disable = [NSLocalizedString("Underline", comment: "")]
        if disable.contains(menuItem.title) {
            menuItem.isHidden = true
        }

        return !disable.contains(menuItem.title)
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

    private var dragDetected = false

    override func mouseDown(with event: NSEvent) {
        guard let note = self.note else { return }
        guard note.container != .encryptedTextPack else {
            editorViewController?.unLock(notes: [note])
            editorViewController?.vcNonSelectedLabel?.isHidden = false
            return
        }

        if editorViewController?.vcEditor?.isPreviewEnabled() == false {
            self.isEditable = true
        }

        dragDetected = false
        saveSelectedRange()
        super.mouseDown(with: event)

        if !self.dragDetected {
            self.handleClick(event)
            self.dragDetected = false
        }
    }

    private func handleClick(_ event: NSEvent) {
        guard let container = self.textContainer,
              let manager = self.layoutManager
        else { return }

        let point = self.convert(event.locationInWindow, from: nil)
        let properPoint = NSPoint(x: point.x - textContainerInset.width, y: point.y)

        let index = manager.characterIndex(for: properPoint, in: container, fractionOfDistanceBetweenInsertionPoints: nil)

        let glyphRect = manager.boundingRect(forGlyphRange: NSRange(location: index, length: 1), in: container)

        guard glyphRect.contains(properPoint) else { return }

        if isTodo(index) {
            guard let f = self.getTextFormatter() else {
                return
            }

            f.toggleTodo(index)

            NSApp.mainWindow?.makeFirstResponder(nil)

            DispatchQueue.main.async {
                NSCursor.pointingHand.set()
            }

            return
        }

        if hasAttachment(at: index) {
            if event.modifierFlags.contains(.command) {
                openTitleEditor(at: index)
            } else {
                openFileViewer(at: index)
            }

            return
        }
    }

    private func openTitleEditor(at: Int) {
        guard let vc = editorViewController,
              let window = vc.view.window,
              var attachment = getAttachment(at: at) else { return }

        vc.alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
        field.placeholderString = "All Hail the Crimson King"
        field.stringValue = attachment.title

        vc.alert?.messageText = NSLocalizedString("Please enter image title:", comment: "Edit area")
        vc.alert?.accessoryView = field
        vc.alert?.alertStyle = .informational
        vc.alert?.addButton(withTitle: "OK")
        vc.alert?.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                attachment.title = field.stringValue

                var range = NSRange()
                if self.textStorage?.attribute(.attachment, at: at, effectiveRange: &range) as? NSTextAttachment != nil {
                    self.textStorage?.addAttribute(.attachmentTitle, value: attachment.title, range: range)

                    let content = NSMutableAttributedString(attributedString: self.attributedString())
                    _ = self.note?.save(content: content)
                }
            }
            vc.alert = nil
        }

        DispatchQueue.main.async {
            field.becomeFirstResponder()
        }
    }

    private func openFileViewer(at: Int) {
        guard let attachment = getAttachment(at: at) else { return }

        let url = attachment.url

        if !url.isImage {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }

        NSWorkspace.shared.open(url)
    }

    override func mouseMoved(with event: NSEvent) {
        if editorViewController?.vcNonSelectedLabel?.isHidden == false {
            NSCursor.arrow.set()
            return
        }

        let point = self.convert(event.locationInWindow, from: nil)
        let properPoint = NSPoint(
            x: point.x - textContainerInset.width,
            y: point.y - textContainerInset.height
        )

        guard let container = self.textContainer,
              let manager = self.layoutManager,
              let textStorage = self.textStorage else { return }

        let index = manager.characterIndex(for: properPoint, in: container, fractionOfDistanceBetweenInsertionPoints: nil)

        guard index < textStorage.length else { return }

        let glyphRect = manager.boundingRect(forGlyphRange: NSRange(location: index, length: 1), in: container)

        if glyphRect.contains(properPoint), self.isTodo(index) || self.hasAttachment(at: index) {
            NSCursor.pointingHand.set()
            return
        }

        if glyphRect.contains(properPoint),
           let link = textStorage.attribute(.link, at: index, effectiveRange: nil) {

            if textStorage.attribute(.tag, at: index, effectiveRange: nil) != nil {
                NSCursor.pointingHand.set()
                return
            }

            if link as? URL != nil {
                if UserDefaultsManagement.clickableLinks
                    || event.modifierFlags.contains(.command)
                    || event.modifierFlags.contains(.shift)
                {
                    NSCursor.pointingHand.set()
                    return
                }

                NSCursor.iBeam.set()
                return
            }
        }

        if editorViewController?.vcEditor?.isPreviewEnabled() == true {
            return
        }

        super.mouseMoved(with: event)
    }

    public func hasAttachment(at: Int) -> Bool {
        guard textStorage?.attribute(.attachment, at: at, effectiveRange: nil) as? NSTextAttachment != nil else {
            return false
        }

        return textStorage?.getMeta(at: at) != nil
    }

    public func getAttachment(at: Int) -> (url: URL, title: String, path: String)? {
        if textStorage?.attribute(.attachment, at: at, effectiveRange: nil) as? NSTextAttachment != nil,
           let meta = textStorage?.getMeta(at: at) {
            return meta
        }

        return nil
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

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        get {
            return [
                NSPasteboard.attributed,
                NSPasteboard.PasteboardType.string,
            ]
        }
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        get {
            return super.readablePasteboardTypes + [NSPasteboard.attributed]
        }
    }

    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard let storage = textStorage else { return false }

        dragDetected = true
        
        let range = selectedRange()
        let attributedString = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: range))

        if type == .string {
            let plainText = attributedString.unloadAttachments().string
            pboard.setString(plainText, forType: .string)
            return true
        }

        if type == NSPasteboard.attributed {
            let attributedString = attributedString.unloadTasks()
            attributedString.saveData()

            if let data = try? NSKeyedArchiver.archivedData(
                withRootObject: attributedString,
                requiringSecureCoding: false
            ) {
                pboard.setData(data, forType: NSPasteboard.attributed)
                return true
            }
        }

        return false
    }

    // Copy empty string
    override func copy(_ sender: Any?) {
        let attrString = attributedSubstring(forProposedRange: self.selectedRange, actualRange: nil)

        if self.selectedRange.length == 1,
            let url = attrString?.attribute(.attachmentUrl, at: 0, effectiveRange: nil) as? URL
        {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([url as NSURL])
            return
        }

        if selectedRanges.count > 1 {
            var combined = String()
            for range in selectedRanges {
                if let range = range as? NSRange, let sub = attributedSubstring(forProposedRange: range, actualRange: nil) as? NSMutableAttributedString {

                    combined.append(sub.unloadAttachments().string + "\n")
                }
            }

            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(combined.trim().removeLastNewLine(), forType: NSPasteboard.PasteboardType.string)
            return
        }

        if self.selectedRange.length == 0, let paragraphRange = self.getParagraphRange(), let paragraph = attributedSubstring(forProposedRange: paragraphRange, actualRange: nil) {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(paragraph.string.trim().removeLastNewLine(), forType: NSPasteboard.PasteboardType.string)
            return
        }
        
        if let menuItem = sender as? NSMenuItem,
           menuItem.identifier?.rawValue == "copy:",
           self.selectedRange.length > 0 {
            
            let attrString = attributedSubstring(forProposedRange: self.selectedRange, actualRange: nil)
            
            if let attrString = attrString,
               let link = attrString.attribute(.link, at: 0, effectiveRange: nil) as? String {
                
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(link, forType: .string)
                return
            }
        }

        super.copy(sender)
    }

    override func paste(_ sender: Any?) {
        guard let note = self.note else { return }
        let start = selectedRange().location

        // RTFD
        if let rtfdData = NSPasteboard.general.data(forType: NSPasteboard.attributed),
           let attributed = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(rtfdData) as? NSAttributedString {

            let mutable = NSMutableAttributedString(attributedString: attributed)
            mutable.loadTasks()

            breakUndoCoalescing()
            insertText(mutable, replacementRange: selectedRange())
            breakUndoCoalescing()
            
            selectInserted(start: start, length: attributed.length)
            return
        }

        // Plain text
        if let clipboard = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string),
            NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.fileURL) == nil {

            let attributed = NSMutableAttributedString(string: clipboard.trim())
            attributed.loadTasks()

            breakUndoCoalescing()
            insertText(attributed, replacementRange: selectedRange())
            breakUndoCoalescing()

            selectInserted(start: start, length: attributed.length)
            return
        }

        if let url = NSURL(from: NSPasteboard.general) {
            if url.isFileURL && saveFile(url: url as URL, in: note) {
                return
            }
        }

        // Images png or tiff
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = NSPasteboard.general.data(forType: type) {
                guard let attributed = NSMutableAttributedString.build(data: data) else { continue }

                breakUndoCoalescing()
                insertText(attributed, replacementRange: selectedRange())
                breakUndoCoalescing()
                
                selectInserted(start: start, length: attributed.length)
                return
            }
        }

        super.paste(sender)
    }
    
    private func selectInserted(start: Int, length: Int) {
        let range = NSRange(location: start, length: length)
        self.setSelectedRange(range)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        let currentRange = selectedRange()
        var plainText: String?

        if let rtfd = NSPasteboard.general.data(forType: NSPasteboard.attributed),
           let attributedString = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(rtfd) as? NSAttributedString {

            let mutable = NSMutableAttributedString(attributedString: attributedString)
            plainText = mutable.unloadAttachments().string
        } else if let clipboard = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string), NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.fileURL) == nil {
            plainText = clipboard
        } else if let url = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.fileURL) {
            plainText = url
        }

        if let plainText = plainText {
            self.breakUndoCoalescing()
            self.insertText(plainText, replacementRange: currentRange)
            self.breakUndoCoalescing()

            return
        }

        return paste(sender)
    }

    override func cut(_ sender: Any?) {
        guard nil != self.note else {
            super.cut(sender)
            return
        }

        if self.selectedRange.length == 0, let paragraphRange = self.getParagraphRange(), let paragraph = attributedSubstring(forProposedRange: paragraphRange, actualRange: nil) {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(paragraph.string.trim().removeLastNewLine(), forType: NSPasteboard.PasteboardType.string)

            insertText(String(), replacementRange: paragraphRange)
            return
        }

        super.cut(sender)
    }

    func getSelectedNote() -> Note? {
        return ViewController.shared()?.notesTableView?.getSelectedNote()
    }
    
    public func isEditable(note: Note) -> Bool {
        if note.container == .encryptedTextPack { return false }

        guard let editor = editorViewController?.vcEditor else { return false }

        if editor.isPreviewEnabled() {
            return false
        }
        
        return true
    }

    public func getVC() -> EditorViewController {
        return self.window?.contentViewController as! EditorViewController
    }
    
    public func getEVC() -> EditorViewController? {
        return self.window?.contentViewController as? EditorViewController
    }

    public func save() {
        guard let note = self.note else { return }

        note.save(attributed: self.attributedString())
    }

    func fill(note: Note, highlight: Bool = false, force: Bool = false) {
        if !note.isLoaded {
            note.load()
        }
        
        viewDelegate?.updateCounters(note: note)

        textStorage?.setAttributedString(NSAttributedString(string: ""))
        
        // Hack for invalidate prev layout data (order is important, only before fill)
        if let length = textStorage?.length {
            textStorage?.layoutManagers.first?.invalidateDisplay(forGlyphRange: NSRange(location: 0, length: length))

            invalidateLayout()
        }

        undoManager?.removeAllActions(withTarget: self)
        registerHandoff(note: note)

        // resets timer if editor refilled 
        viewDelegate?.breakUndoTimer.invalidate()

        unregisterDraggedTypes()
        registerForDraggedTypes([
            NSPasteboard.note,
            NSPasteboard.PasteboardType.fileURL,
            NSPasteboard.PasteboardType.URL,
            NSPasteboard.PasteboardType.string
        ])

        if let label = editorViewController?.vcNonSelectedLabel {
            label.isHidden = true

            if note.container == .encryptedTextPack {
                label.stringValue = NSLocalizedString("Locked", comment: "")
                label.isHidden = false
            } else {
                label.stringValue = NSLocalizedString("None Selected", comment: "")
                label.isHidden = true
            }
        }
    
        self.note = note
        UserDefaultsManagement.lastSelectedURL = note.url

        editorViewController?.updateTitle(note: note)

        isEditable = isEditable(note: note)
        
        editorViewController?.editorUndoManager = note.undoManager

        typingAttributes.removeAll()
        typingAttributes[.font] = UserDefaultsManagement.noteFont

        if isPreviewEnabled() {
            loadMarkdownWebView(note: note, force: force)
            return
        }

        markdownView?.removeFromSuperview()
        markdownView = nil

        guard let storage = textStorage else { return }

        if note.isMarkdown(), let content = note.content.mutableCopy() as? NSMutableAttributedString {
            textStorageProcessor?.detector = CodeBlockDetector()

            storage.setAttributedString(content)
        } else {
            storage.setAttributedString(note.content)
        }
        
        if highlight {
            textStorage?.highlightKeyword(search: getSearchText())
        }

        loadSelectedRange()
    }

    private func loadMarkdownWebView(note: Note, force: Bool) {
        self.note = nil
        textStorage?.setAttributedString(NSAttributedString())
        self.note = note

        guard let scrollView = editorViewController?.vcEditorScrollView else { return }
        
        if markdownView == nil {
            let frame = scrollView.bounds
            markdownView = MPreviewView(frame: frame, note: note, closure: {})
            markdownView?.setEditorVC(evc: editorViewController)
            if let view = self.markdownView, self.note == note {
                scrollView.addSubview(view)
            }
        } else {
            /// Resize markdownView
            let frame = scrollView.bounds
            markdownView?.frame = frame

            /// Load note if needed
            markdownView?.load(note: note, force: force)
        }
    }

    public func lockEncryptedView() {
        textStorage?.setAttributedString(NSAttributedString())
        markdownView?.removeFromSuperview()
        markdownView = nil

        isEditable = false
        
        if let label = editorViewController?.vcNonSelectedLabel {
            label.stringValue = NSLocalizedString("Locked", comment: "")
            label.isHidden = false
        }
    }
    
    public func clear() {
        textStorage?.setAttributedString(NSAttributedString())
        markdownView?.removeFromSuperview()
        markdownView = nil

        isEditable = false
        
        window?.title = AppDelegate.appTitle
        
        if let label = editorViewController?.vcNonSelectedLabel {
            label.stringValue = NSLocalizedString("None Selected", comment: "")
            label.isHidden = false
            editorViewController?.dropTitle()
        }
        
        self.note = nil
        
        if let vc = viewDelegate {
            vc.updateCounters()
        }
    }

    @IBAction func boldMenu(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.bold()
    }

    @IBAction func italicMenu(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.italic()
    }

    @IBAction func linkMenu(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.link()
    }

    @IBAction func underlineMenu(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.underline()
    }

    @IBAction func strikeMenu(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.strike()
    }

    @IBAction func headerMenu(_ sender: NSMenuItem) {
        guard let note = self.note, isEditable else { return }

        guard let id = sender.identifier?.rawValue else { return }

        let code =
            Int(id.replacingOccurrences(of: "format.h", with: ""))

        var string = String()
        for index in [1, 2, 3, 4, 5, 6] {
            string = string + "#"
            if code == index {
                break
            }
        }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.header(string)
    }
    
    @IBAction func moveSelectedLinesDown(_ sender: NSMenuItem) {
        self.moveSelectedLinesDown()
    }
    
    @IBAction func moveSelectedLinesUp(_ sender: NSMenuItem) {
        self.moveSelectedLinesUp()
    }
    
    @IBAction func clearCompletedTodos(_ sender: NSMenuItem) {
        self.clearCompletedTodos()
    }

    func getParagraphRange() -> NSRange? {
        guard let storage = textStorage else { return nil }
        
        let range = selectedRange()
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

    // Clickable links flag changed with cmd / shift
    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)

        if let mouseEvent = NSApp.currentEvent {
            updateCursorForMouse(at: mouseEvent)
        }
    }

    private func updateCursorForMouse(at event: NSEvent) {
        guard let container = self.textContainer,
              let manager = self.layoutManager,
              let textStorage = self.textStorage else { return }

        let pointInView = self.convert(event.locationInWindow, from: nil)
        
        let pointInContainer = NSPoint(
            x: pointInView.x - textContainerInset.width,
            y: (self.bounds.size.height - pointInView.y) - textContainerInset.height
        )

        let index = manager.characterIndex(
            for: pointInContainer,
            in: container,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        guard index < textStorage.length else {
            NSCursor.iBeam.set()
            return
        }

        if let link = textStorage.attribute(.link, at: index, effectiveRange: nil) {
            if textStorage.attribute(.tag, at: index, effectiveRange: nil) != nil {
                NSCursor.pointingHand.set()
            } else if link as? URL != nil {
                if UserDefaultsManagement.clickableLinks
                    || NSEvent.modifierFlags.contains(.command)
                    || NSEvent.modifierFlags.contains(.shift) {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.iBeam.set()
                }
            }
        } else {
            NSCursor.iBeam.set()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        defer {
            saveSelectedRange()
        }
        
        // fixes backtick marked text 
        if event.keyCode == kVK_ANSI_Grave {
            super.insertText("`", replacementRange: selectedRange())
            return
        }

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
        
        guard let note = self.note else { return }
        
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
            } else {
                super.keyDown(with: event)
                self.insertText(closingBracket, replacementRange: selectedRange())
                self.moveBackward(self)
            }
            return
        }

        // hasMarkedText added for Japanese hack https://yllan.org/blog/archives/231
        if event.keyCode == kVK_Tab && !hasMarkedText(){
            breakUndoCoalescing()
            
            let formatter = TextFormatter(textView: self, note: note)
            if formatter.isListParagraph() {
                if NSEvent.modifierFlags.contains(.shift) {
                    formatter.unTab()
                } else {
                    formatter.tab()
                }
                
                breakUndoCoalescing()
                return
            }
            
            if UserDefaultsManagement.indentUsing == 0x01 {
                let tab = TextFormatter.getAttributedCode(string: "  ")
                insertText(tab, replacementRange: selectedRange())
                breakUndoCoalescing()
                return
            }
            
            if UserDefaultsManagement.indentUsing == 0x02 {
                let tab = TextFormatter.getAttributedCode(string: "    ")
                insertText(tab, replacementRange: selectedRange())
                breakUndoCoalescing()
                return
            }

            super.keyDown(with: event)
            return
        }

        if event.keyCode == kVK_Return && !hasMarkedText() && isEditable {
            breakUndoCoalescing()
            let formatter = TextFormatter(textView: self, note: note)
            formatter.newLine()
            breakUndoCoalescing()
            return
        }

        if event.keyCode == kVK_Delete && event.modifierFlags.contains(.option) {
            deleteWordBackward(nil)
            return
        }

        if event.characters?.unicodeScalars.first == "o" && event.modifierFlags.contains(.command) {
            guard let storage = textStorage else { return }

            var location = selectedRange().location
            if location == storage.length && location > 0 {
                location = location - 1
            }

            if storage.length > location, let link = textStorage?.attribute(.link, at: location, effectiveRange: nil) as? String {

                if link.isValidEmail(), let mail = URL(string: "mailto:\(link)") {
                    NSWorkspace.shared.open(mail)
                } else if let url = URL(string: link) {
                    _ = try? NSWorkspace.shared.open(url, options: .default, configuration: [:])
                }
            }

            return
        }
        
        super.keyDown(with: event)
    }
    
    override func shouldChangeText(in range: NSRange, replacementString: String?) -> Bool {
        guard let note = self.note else {
            return super.shouldChangeText(in: range, replacementString: replacementString)
        }

        note.resetAttributesCache()
                
        scheduleTagScan(for: note)
        deleteUnusedImages(checkRange: range)
        resetTypingAttributes()

        return super.shouldChangeText(in: range, replacementString: replacementString)
    }
    
    // MARK: Autocomplete overrides
    
    var suppressCompletion = false
    
    public var forceSystemAutocomplete = false
    private var isSystemCompletionSession = false
    
    override func didChangeText() {
        super.didChangeText()
        
        if suppressCompletion {
            suppressCompletion = false
            return
        }
        
        if detectCompletionContext() != .none {
            complete(nil)
        }
    }
    
    override func completions(forPartialWordRange charRange: NSRange,
                              indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {

        if forceSystemAutocomplete {
            isSystemCompletionSession = true
            forceSystemAutocomplete = false
            return super.completions(forPartialWordRange: charRange, indexOfSelectedItem: index)
        }

        return handleCompletions(index: index)
    }

    override func insertCompletion(_ word: String,
                                   forPartialWordRange charRange: NSRange,
                                   movement: Int,
                                   isFinal flag: Bool) {

        if isSystemCompletionSession {
            super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: flag)

            if flag {
                isSystemCompletionSession = false
            }
            return
        }

        handleInsertCompletion(word: word, movement: movement, isFinal: flag)
    }

    override var rangeForUserCompletion: NSRange {
        if isSystemCompletionSession {
            return super.rangeForUserCompletion
        }

        return calculateCompletionRange()
    }
    
    @objc public func scanTagsAndAutoRename() {
        guard let vc = ViewController.shared() else { return }
        let notes = vc.tagsScannerQueue

        attributesCachingQueue.addOperation {
            for note in notes {
                note.cache()
            }
        }
        
        for note in notes {
            let result = note.scanContentTags()
            guard let outline = ViewController.shared()?.sidebarOutlineView else { return }

            let added = result.0
            let removed = result.1

            if removed.count > 0 {
                outline.removeTags(removed)
            }

            if added.count > 0 {
                outline.addTags(added)
            }

            if let title = note.getAutoRenameTitle() {
                note.rename(to: title)

                if let editorViewController = getEVC() {
                    editorViewController.vcTitleLabel?.updateNotesTableView()
                    editorViewController.updateTitle(note: note)
                }
            }

            ViewController.shared()?.tagsScannerQueue.removeAll(where: { $0 === note })
        }
    }

    func saveSelectedRange() {
        guard let note = self.note, let range = selectedRanges[0] as? NSRange else {
            return
        }

        note.setSelectedRange(range: range) 
    }
    
    func loadSelectedRange() {
        guard let storage = textStorage else { return }

        if let range = self.note?.getSelectedRange(), range.upperBound <= storage.length {
            setSelectedRange(range)
            scrollToCursor()
        }
    }

    func setEditorTextColor(_ color: NSColor) {
        if let note = self.note, !note.isMarkdown() {
            textColor = color
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        imagesLoaderQueue.maxConcurrentOperationCount = 3
        imagesLoaderQueue.qualityOfService = .userInteractive
    }

    override var textContainerOrigin: NSPoint {
        let origin = super.textContainerOrigin
        return NSPoint(x: origin.x, y: origin.y - 7)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let note = self.note, let storage = textStorage else { return false }
        
        let pasteboard = sender.draggingPasteboard
        let dropPoint = convert(sender.draggingLocation, from: nil)
        let caretLocation = characterIndexForInsertion(at: dropPoint)
        let replacementRange = NSRange(location: caretLocation, length: 0)

        if handleAttributedText(pasteboard, note: note, storage: storage, replacementRange: replacementRange) { return true }
        if handleNoteReference(pasteboard, note: note, replacementRange: replacementRange) { return true }
        if handleURLs(pasteboard, note: note, replacementRange: replacementRange) { return true }

        return super.performDragOperation(sender)
    }

    func fetchDataFromURL(url: URL, completion: @escaping (Data?, Error?) -> Void) {
        let session = URLSession.shared

        let task = session.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completion(nil, error)
                return
            }

            completion(data, nil)
        }

        task.resume()
    }

    
    func getHTMLTitle(from data: Data) -> String? {
        guard let htmlString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return extractTitle(from: htmlString)
    }

    func getSearchText() -> String {
        guard let search = ViewController.shared()?.search else { return String() }

        if let editor = search.currentEditor(), editor.selectedRange.length > 0 {
            return (search.stringValue as NSString).substring(with: NSRange(0..<editor.selectedRange.location))
        }
        
        return search.stringValue
    }

    public func scrollToCursor() {
        let cursorRange = NSMakeRange(self.selectedRange().location, 0)

        // DispatchQueue fixes rare bug when textStorage invalidation not working (blank page instead text)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.scrollRangeToVisible(cursorRange)
        }
    }
    
    public func hasFocus() -> Bool {
        if let fr = self.window?.firstResponder, fr.isKind(of: EditTextView.self) {
            return true
        }
        
        return false
    }

    @IBAction func shiftLeft(_ sender: Any) {
        guard let note = self.note, isEditable else { return }
        let f = TextFormatter(textView: self, note: note)
        f.unTab()
    }
    
    @IBAction func shiftRight(_ sender: Any) {
        guard let note = self.note, isEditable else { return }
        let f = TextFormatter(textView: self, note: note)
        f.tab()
    }

    @IBAction func todo(_ sender: Any) {
        guard let f = self.getTextFormatter(), isEditable else { return }
        
        f.todo()
    }

    @IBAction func wikiLinks(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.wikiLink()
    }

    @IBAction func pressBold(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.bold()
    }

    @IBAction func pressItalic(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.italic()
    }
    
    @IBAction func insertFileOrImage(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = true
        panel.begin { (result) -> Void in
            if result == NSApplication.ModalResponse.OK {
                let urls = panel.urls

                for url in urls {
                    if self.saveFile(url: url, in: note) {
                        if urls.count > 1 {
                            self.insertNewline(nil)
                        }
                    }
                }

                if let vc = ViewController.shared() {
                    vc.notesTableView.reloadRow(note: note)
                }
            }
        }
    }

    @IBAction func insertCodeBlock(_ sender: NSButton) {
        guard isEditable else { return }

        let currentRange = selectedRange()

        if currentRange.length > 0 {
            let mutable = NSMutableAttributedString(string: "```\n")
            if let substring = attributedSubstring(forProposedRange: currentRange, actualRange: nil) {
                mutable.append(substring)

                if substring.string.last != "\n" {
                    mutable.append(NSAttributedString(string: "\n"))
                }
            }

            mutable.append(NSAttributedString(string: "```\n"))

            insertText(mutable, replacementRange: currentRange)
            setSelectedRange(NSRange(location: currentRange.location + 3, length: 0))
            
            return
        }
        
        insertText("```\n\n```\n", replacementRange: currentRange)
        setSelectedRange(NSRange(location: currentRange.location + 3, length: 0))
    }

    @IBAction func insertCodeSpan(_ sender: NSMenuItem) {
        guard isEditable else { return }

        let currentRange = selectedRange()

        if currentRange.length > 0 {
            let mutable = NSMutableAttributedString(string: "`")
            if let substring = attributedSubstring(forProposedRange: currentRange, actualRange: nil) {
                mutable.append(substring)
            }

            mutable.append(NSAttributedString(string: "`"))

            insertText(mutable, replacementRange: currentRange)
            return
        }

        insertText("``", replacementRange: currentRange)
        setSelectedRange(NSRange(location: currentRange.location + 1, length: 0))
    }

    @IBAction func insertList(_ sender: NSMenuItem) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.list()
    }

    @IBAction func insertOrderedList(_ sender: NSMenuItem) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.orderedList()
    }

    @IBAction func insertQuote(_ sender: NSMenuItem) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.quote()
    }

    @IBAction func insertLink(_ sender: Any) {
        guard let note = self.note, isEditable else { return }

        let formatter = TextFormatter(textView: self, note: note)
        formatter.link()
    }
    
    private func getTextFormatter() -> TextFormatter? {
        guard let note = self.note, isEditable else { return nil }
        
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

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.data(forType: NSPasteboard.note) != nil {
            let dropPoint = convert(sender.draggingLocation, from: nil)
            let caretLocation = characterIndexForInsertion(at: dropPoint)
            setSelectedRange(NSRange(location: caretLocation, length: 0))
            return .copy
        }

        return super.draggingUpdated(sender)
    }
    
    override func clicked(onLink link: Any, at charIndex: Int) {
        if handleEmailLink(link) { return }
        
        if handleAnchorLink(link) { return }

        if !isAttachmentAtPosition(charIndex) {
            if handleRegularLink(link, at: charIndex) { return }
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        UserDataService.instance.isDark = effectiveAppearance.isDark
        storage.resetCacheAttributes()

        // clear preview cache
        MPreviewView.template = nil
        let webkitPreview = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wkPreview")
        try? FileManager.default.removeItem(at: webkitPreview)

        NotesTextProcessor.hl = nil

        guard let note = self.note else { return }
        NotesTextProcessor.highlight(attributedString: note.content)

        let funcName = effectiveAppearance.isDark ? "switchToDarkMode" : "switchToLightMode"
        let switchScript = "if (typeof(\(funcName)) == 'function') { \(funcName)(); }"

        downView?.evaluateJavaScript(switchScript)

        viewDelegate?.refillEditArea(force: true)
    }

    private func saveFile(url: URL, in note: Note) -> Bool {
        if let data = try? Data(contentsOf: url) {
            let preferredName = url.lastPathComponent

            guard let attributed = NSMutableAttributedString.build(data: data, preferredName: preferredName) else { return false }

            breakUndoCoalescing()
            insertText(attributed, replacementRange: selectedRange())
            breakUndoCoalescing()

            return true
        }

        return false
    }

    public func updateTextContainerInset() {
        textContainerInset.width = getInsetWidth()
    }

    public func getInsetWidth() -> CGFloat {
        let lineWidth = UserDefaultsManagement.lineWidth
        let margin = UserDefaultsManagement.marginSize
        let width = frame.width

        if lineWidth == 1000 {
            return CGFloat(margin)
        }

        guard Float(width) - margin * 2 > lineWidth else {
            return CGFloat(margin)
        }

        return CGFloat((Float(width) - lineWidth) / 2)
    }

    private func deleteUnusedImages(checkRange: NSRange) {
        guard let storage = textStorage, self.note != nil else { return }

        storage.enumerateAttribute(.attachment, in: checkRange) { (value, range, _) in
            guard let meta = storage.getMeta(at: range.location) else { return }

            do {
                if let data = try? Data(contentsOf: meta.url) {
                    storage.addAttribute(.attachmentSave, value: data, range: range)

                    try FileManager.default.removeItem(at: meta.url)
                }
            } catch {
                print(error)
            }
        }
    }

    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [
            NSTouchBarItem.Identifier("Todo"),
            NSTouchBarItem.Identifier("Bold"),
            NSTouchBarItem.Identifier("Italic"),
            .fixedSpaceSmall,
            NSTouchBarItem.Identifier("Link"),
            NSTouchBarItem.Identifier("Image or file"),
            NSTouchBarItem.Identifier("CodeBlock"),
            .fixedSpaceSmall,
            NSTouchBarItem.Identifier("Indent"),
            NSTouchBarItem.Identifier("UnIndent")
        ]
        return touchBar
    }

    @available(OSX 10.12.2, *)
    override func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case NSTouchBarItem.Identifier("Todo"):
            if let im = NSImage(named: "todo"), im.isValid, im.size.height > 0 {
                let image = im.tint(color: NSColor.white)
                image.size = NSSize(width: 20, height: 20)
                let button = NSButton(image: image, target: self, action: #selector(todo(_:)))
                button.bezelColor = NSColor(red:0.21, green:0.21, blue:0.21, alpha:1.0)

                let customViewItem = NSCustomTouchBarItem(identifier: identifier)
                customViewItem.view = button
                return customViewItem
            }
        case NSTouchBarItem.Identifier("Bold"):
            if let im = NSImage(named: "bold"), im.isValid, im.size.height > 0 {
                let image = im.tint(color: NSColor.white)
                image.size = NSSize(width: 20, height: 20)
                let button = NSButton(image: image, target: self, action: #selector(pressBold(_:)))
                button.bezelColor = NSColor(red:0.21, green:0.21, blue:0.21, alpha:1.0)

                let customViewItem = NSCustomTouchBarItem(identifier: identifier)
                customViewItem.view = button
                return customViewItem
            }
        case NSTouchBarItem.Identifier("Italic"):
            if let im = NSImage(named: "italic"), im.isValid, im.size.height > 0 {
                let image = im.tint(color: NSColor.white)
                image.size = NSSize(width: 20, height: 20)
                let button = NSButton(image: image, target: self, action: #selector(pressItalic(_:)))
                button.bezelColor = NSColor(red:0.21, green:0.21, blue:0.21, alpha:1.0)

                let customViewItem = NSCustomTouchBarItem(identifier: identifier)
                customViewItem.view = button
                return customViewItem
            }
        case NSTouchBarItem.Identifier("Image or file"):
            if let im = NSImage(named: "image"), im.isValid, im.size.height > 0 {
                let image = im.tint(color: NSColor.white)
                image.size = NSSize(width: 20, height: 20)
                let button = NSButton(image: image, target: self, action: #selector(insertFileOrImage(_:)))
                button.bezelColor = NSColor(red:0.21, green:0.21, blue:0.21, alpha:1.0)

                let customViewItem = NSCustomTouchBarItem(identifier: identifier)
                customViewItem.view = button
                return customViewItem
            }

        case NSTouchBarItem.Identifier("Indent"):
            if let im = NSImage(named: "indent"), im.isValid, im.size.height > 0 {
                let image = im.tint(color: NSColor.white)
                image.size = NSSize(width: 20, height: 20)
                let button = NSButton(image: image, target: self, action: #selector(shiftRight(_:)))
                button.bezelColor = NSColor(red:0.21, green:0.21, blue:0.21, alpha:1.0)

                let customViewItem = NSCustomTouchBarItem(identifier: identifier)
                customViewItem.view = button
                return customViewItem
            }

        case NSTouchBarItem.Identifier("UnIndent"):
            if let im = NSImage(named: "unindent"), im.isValid, im.size.height > 0 {
                let image = im.tint(color: NSColor.white)
                image.size = NSSize(width: 20, height: 20)
                let button = NSButton(image: image, target: self, action: #selector(shiftLeft(_:)))
                button.bezelColor = NSColor(red:0.21, green:0.21, blue:0.21, alpha:1.0)

                let customViewItem = NSCustomTouchBarItem(identifier: identifier)
                customViewItem.view = button
                return customViewItem
            }
        case NSTouchBarItem.Identifier("CodeBlock"):
            if let im = NSImage(named: "codeblock"), im.isValid, im.size.height > 0 {
                let image = im.tint(color: NSColor.white)
                image.size = NSSize(width: 20, height: 20)
                let button = NSButton(image: image, target: self, action: #selector(insertCodeBlock(_:)))
                button.bezelColor = NSColor(red:0.21, green:0.21, blue:0.21, alpha:1.0)

                let customViewItem = NSCustomTouchBarItem(identifier: identifier)
                customViewItem.view = button
                return customViewItem
            }
        case NSTouchBarItem.Identifier("Link"):
            if let im = NSImage(named: "tb_link"), im.isValid, im.size.height > 0 {
                let image = im.tint(color: NSColor.white)
                image.size = NSSize(width: 20, height: 20)
                let button = NSButton(image: image, target: self, action: #selector(insertLink(_:)))
                button.bezelColor = NSColor(red:0.21, green:0.21, blue:0.21, alpha:1.0)

                let customViewItem = NSCustomTouchBarItem(identifier: identifier)
                customViewItem.view = button
                return customViewItem
            }
        default: break
        }

        return super.touchBar(touchBar, makeItemForIdentifier: identifier)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)

        let editTitle = NSLocalizedString("Edit Link…", comment: "")
        if let editLink = menu?.item(withTitle: editTitle) {
            menu?.removeItem(editLink)
        }

        let removeTitle = NSLocalizedString("Remove Link", comment: "")
        if let removeLink = menu?.item(withTitle: removeTitle) {
            menu?.removeItem(removeLink)
        }

        return menu
    }

    /**
     Handoff methods
     */
    override func updateUserActivityState(_ userActivity: NSUserActivity) {
        guard let note = self.note else { return }

        let position =
            window?.firstResponder == self ? selectedRange().location : -1
        let state = editorViewController?.vcEditor?.preview == true ? "preview" : "editor"
        let data =
            [
                "note-file-name": note.name,
                "position": String(position),
                "state": state
            ]

        userActivity.addUserInfoEntries(from: data)
    }

    override func resignFirstResponder() -> Bool {
        userActivity?.needsSave = true

        return super.resignFirstResponder()
    }

    public func registerHandoff(note: Note) {
        self.userActivity?.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let updateDict:  [String: String] = ["note-file-name": note.name]
            let activity = NSUserActivity(activityType: "es.fsnot.handoff-open-note")
            activity.isEligibleForHandoff = true
            activity.userInfo = updateDict
            activity.title = NSLocalizedString("Open note", comment: "Document opened")
            self.userActivity = activity
            self.userActivity?.becomeCurrent()
        }
    }
    
    public func changePreviewState(_ state: Bool) {
        preview = state
    }
    
    public func togglePreviewState() {
        self.preview = !self.preview
        
        note?.previewState = self.preview
    }
    
    public func isPreviewEnabled() -> Bool {
        return preview
    }
    
    public func disablePreviewEditorAndNote() {
        preview = false
        
        note?.previewState = false
    }
    
    public func scheduleTagScan(for note: Note) {
        if let vc = ViewController.shared(),
           !vc.tagsScannerQueue.contains(note) {
            vc.tagsScannerQueue.append(note)
        }

        tagsTimer?.invalidate()
        tagsTimer = Timer.scheduledTimer(
            timeInterval: 2.5,
            target: self,
            selector: #selector(scanTagsAndAutoRename),
            userInfo: nil,
            repeats: false
        )
    }

    public func resetTypingAttributes() {
        typingAttributes.removeValue(forKey: .todo)
        typingAttributes.removeValue(forKey: .tag)

        if let style = typingAttributes[.paragraphStyle] as? NSMutableParagraphStyle {
            style.alignment = .left
        }
    }
}
