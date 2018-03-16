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

class EditTextView: NSTextView {
    public static var note: Note?
    var isHighlighted: Bool = false
    
    class UndoInfo: NSObject {
        let text: String
        let replacementRange: NSRange
        
        init(text: String, replacementRange: NSRange) {
            self.text = text
            self.replacementRange = replacementRange
        }
    }
    
    var downView: MarkdownView?
    
    override func drawBackground(in rect: NSRect) {
        backgroundColor = UserDefaultsManagement.bgColor
        
        super.drawBackground(in: rect)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
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
        if let notes = Storage.instance.getBy(startWith: chars) {
            let titles = notes.map{ $0.title }
            return titles
        }
        return nil
    }
    
    @IBAction func editorMenuItem(_ sender: Any) {
        let keyEquivalent = (sender as AnyObject).keyEquivalent.lowercased()
        
        let dict = ["b": 11, "i": 34, "j": 38, "y": 16, "u": 32, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22] as [String: UInt16]
        
        if (dict[keyEquivalent] != nil) {
            let keyCode = dict[keyEquivalent]!
            let modifier = (sender as AnyObject).keyEquivalentModifierMask.rawValue == 262144 ? 393475 : 0
            
            _ = formatShortcut(keyCode: keyCode, modifier: UInt(modifier))
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
            viewController.makeNote(NSTextField())
        }
        return super.mouseDown(with: event)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        /* Skip command-shift-b conflicted with cmd-b */
        if event.modifierFlags.contains(NSEvent.ModifierFlags.command) && event.modifierFlags.contains(NSEvent.ModifierFlags.shift) && event.keyCode == 11 {
            return super.performKeyEquivalent(with: event)
        }
        
        if (event.modifierFlags.contains(NSEvent.ModifierFlags.command) || event.modifierFlags.rawValue == 393475) {
            if (formatShortcut(keyCode: event.keyCode, modifier: event.modifierFlags.rawValue as UInt)) {
                return true
            }
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
        undoManager?.removeAllActions()
        
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
                downView = try? MarkdownView(frame: (self.superview?.bounds)!, markdownString: markdownString, css: css, templateBundle: bundle) {
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
      
        self.window?.title = note.title
        setSelectedRange(NSRange(location: 0, length: 0))
    }
    
    @objc func loadImages() {
        if let note = self.getSelectedNote() {
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
    }
    
    func formatShortcut(keyCode: UInt16, modifier: UInt = 0) -> Bool {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let editArea = viewController.editArea!
        
        guard let note = getSelectedNote(), !UserDefaultsManagement.preview else {
            return false
        }
        
        if (!editArea.isEditable) {
            return false
        }

        let text = editArea.textStorage!.string as NSString
        let range = editArea.selectedRange()
        let selectedText = text.substring(with: range) as NSString
        
        let attributedSelected = editArea.attributedSubstring(forProposedRange: range, actualRange: nil)
        var attributedText = NSMutableAttributedString()
        
        if (attributedSelected == nil) {
           attributedText.addAttributes([.font: UserDefaultsManagement.noteFont], range: NSMakeRange(0, selectedText.length))
        } else {
            attributedText = NSMutableAttributedString(attributedString: attributedSelected!)
        }
        
        if typingAttributes[.font] == nil {
            typingAttributes[.font] = UserDefaultsManagement.noteFont
        }
        
        switch keyCode {
        case 11: // cmd-b
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.bold()
            return true
        case 34:
            // control-shift-i
            if (note.type == .Markdown && modifier == 393475) {
                attributedText.mutableString.setString("![](" + attributedText.string + ")")
                break
            }
        
            // cmd-i
            let formatter = TextFormatter(textView: editArea, note: note)
            formatter.italic()
            return true
        case 32: // cmd-u
            if note.type == .RichText {
                if (selectedText.length > 0) {
                    attributedText.removeAttribute(NSAttributedStringKey(rawValue: "NSUnderline"), range: NSMakeRange(0, selectedText.length))
                }
                
                if (typingAttributes[.underlineStyle] == nil) {
                    attributedText.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue, range: NSMakeRange(0, selectedText.length))
                    typingAttributes[.underlineStyle] = 1
                } else {
                    typingAttributes.removeValue(forKey: NSAttributedStringKey(rawValue: "NSUnderline"))
                }
            }
            break
        case 16: // cmd-y
            if note.type == .RichText {
                if (selectedText.length > 0) {
                    attributedText.removeAttribute(NSAttributedStringKey(rawValue: "NSStrikethrough"), range: NSMakeRange(0, selectedText.length))
                }
                
                if (typingAttributes[.strikethroughStyle] == nil) {
                    attributedText.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 2, range: NSMakeRange(0, selectedText.length))
                    typingAttributes[.strikethroughStyle] = 2
                } else {
                    typingAttributes.removeValue(forKey: NSAttributedStringKey(rawValue: "NSStrikethrough"))
                }
            }
            
            if note.type == .Markdown {
                attributedText.mutableString.setString("~~" + attributedText.string + "~~")
            }
        case (18...23): // cmd-1/6 (headers 1/6)
            if note.type == .Markdown {
                var string = ""
                var offset = 2
                
                for index in [18,19,20,21,23,22] {
                    string = string + "#"
                    if Int(keyCode) == index {
                        break
                    }
                    offset = offset + 1
                }
                
                attributedText.mutableString.setString(string + " " + attributedText.string)
            }
            break
        case 38: // control-shift-j (link)
            if (note.type == .Markdown && modifier == 393475) {
                attributedText.mutableString.setString("[](" + attributedText.string + ")")
            }
            break
        default:
            return false
        }
        
        editArea.textStorage!.replaceCharacters(in: range, with: attributedText)
        
        if note.type == .RichText {
            editArea.setSelectedRange(range)
            note.content = NSMutableAttributedString(attributedString: editArea.attributedString())
            note.save()
            return true
        }

        if note.type == .Markdown, let paragraphRange = getParagraphRange() {
            NotesTextProcessor.scanMarkdownSyntax(editArea.textStorage!, paragraphRange: paragraphRange, note: note)
            
            note.content = NSMutableAttributedString(attributedString: editArea.attributedString())
            note.save()
            
            return true
        }
        
        return false
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
        
        note.save()
        
        if UserDefaultsManagement.liveImagesPreview {
            let processor = ImagesProcessor(styleApplier: storage, range: range, maxWidth: frame.width, note: note)
            processor.load()
        }
        
        cacheNote(note: note)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 {
            guard let note = EditTextView.note else {
                return
            }
            
            if event.modifierFlags.rawValue == 131330 {
                let formatter = TextFormatter(textView: self, note: note)
                formatter.unTab()
                return
            }
            
            let formatter = TextFormatter(textView: self, note: note)
            formatter.tab()
            return
        }

        guard let note = EditTextView.note else {
            return
        }
        
        if note.type == .PlainText || note.type == .RichText {
            super.keyDown(with: event)
            
            let range = getParagraphRange()
            let processor = NotesTextProcessor(storage: textStorage, range: range)
            processor.higlightLinks()
            
            if note.type == .RichText {
                cacheNote(note: note)
            }
            
            return
        }
        
        super.keyDown(with: event)
        
        let range = selectedRanges[0] as! NSRange
        guard let storage = textStorage, note.content.length >= range.location + range.length else {
            return
        }
        
        let processor = NotesTextProcessor(note: note, storage: storage, range: range, maxWidth: frame.width)
        processor.scanParagraph()
        cacheNote(note: note)
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
        registerForDraggedTypes([NSPasteboard.PasteboardType(kUTTypeFileURL as String)])
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let board = sender.draggingPasteboard()
        var data: Data
        
        guard let note = getSelectedNote(), let storage = textStorage, let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
            urls.count > 0 else {
            return false
        }
        
        let url = urls[0]
        
        do {
            data = try Data(contentsOf: url)
        } catch {
            return false
        }
        
        let processor = ImagesProcessor(styleApplier: storage, maxWidth: frame.width, note: note)
        
        guard let fileName = processor.writeImage(data: data, url: url), let name = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return false
        }
        
        let dropPoint = convert(sender.draggingLocation(), from: nil)
        let caretLocation = characterIndexForInsertion(at: dropPoint)
        let affectedRange = NSRange(location: caretLocation, length: 0)
        
        replaceCharacters(in: affectedRange, with: "![](/i/\(name))")
        
        note.save()
        
        if let paragraphRange = getParagraphRange() {
            NotesTextProcessor.scanMarkdownSyntax(storage, paragraphRange: paragraphRange, note: note)
            cacheNote(note: note)
        }
        
        loadImages()
        return true
    }
    
    func getSearchText() -> String {
        let mainWindow = NSApplication.shared.windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let search = viewController.search.stringValue
        
        return search
    }
    
}
