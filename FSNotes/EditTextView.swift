//
//  EditTextView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/11/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class EditTextView: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    func getSelectedNote() -> Note {
        let mainWindow = NSApplication.shared().windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let note = viewController.notesTableView.getNoteFromSelectedRow()
        return note
    }
        
    func fill(note: Note) {
        self.isEditable = true
        self.isRichText = note.isRTF()

        let attrString = createAttributedString(note: note)
        self.textStorage?.setAttributedString(attrString)
        
        if (!getSelectedNote().isRTF()) {
            self.textStorage?.font = UserDefaultsManagement.noteFont
        }
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = true
    }
    
    func save(note: Note) -> Bool {
        let fileUrl = note.url
        let fileExtension = fileUrl?.pathExtension
        
        do {
            let range = NSRange(location:0, length: (textStorage?.string.characters.count)!)
            let documentAttributes = DocumentAttributes.getDocumentAttributes(fileExtension: fileExtension!)
            
            if (fileExtension == "rtf") {
                let text = try textStorage?.fileWrapper(from: range, documentAttributes: documentAttributes)
                
                try text?.write(to: fileUrl!, options: FileWrapper.WritingOptions.atomic, originalContentsURL: nil)
            } else {
                textStorage?.setAttributes(documentAttributes, range: range)
                
                try textStorage?.string.write(to: fileUrl!, atomically: false, encoding: String.Encoding.utf8)
            }
            
            return true
        } catch let error {
            NSLog(error.localizedDescription)
        }
        
        return false
    }
    
    func clear() {
        textStorage?.mutableString.setString("")
        isEditable = false
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = false
    }
    
    func createAttributedString(note: Note) -> NSAttributedString {
        let url = note.url
        let fileExtension = url?.pathExtension
        let options = DocumentAttributes.getDocumentAttributes(fileExtension: fileExtension!)
        var attributedString = NSAttributedString()
        
        do {
            attributedString = try NSAttributedString(url: url!, options: options, documentAttributes: nil)
        } catch {
            NSLog("No text content found!")
        }
        
        return attributedString
    }
    
    override func mouseDown(with event: NSEvent) {
        let viewController = self.window?.contentViewController as! ViewController
        if (!viewController.emptyEditAreaImage.isHidden) {
            viewController.makeNote(NSTextField())
        }
        return super.mouseDown(with: event)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if (event.modifierFlags.contains(.command) || event.modifierFlags.rawValue == 393475) {
            if (formatter(keyCode: event.keyCode, modifier: event.modifierFlags.rawValue as UInt)) {
                return true
            }
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    func formatter(keyCode: UInt16, modifier: UInt = 0) -> Bool {
        let mainWindow = NSApplication.shared().windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let editArea = viewController.editArea!
        
        let currentNote = getSelectedNote()
        let range = editArea.selectedRange()
        let text = editArea.textStorage!.string as NSString
        let selectedText = text.substring(with: range) as NSString
    
        let attributedText = NSMutableAttributedString(string: selectedText as String)
        let options = DocumentAttributes.getDocumentAttributes(fileExtension: currentNote.url.pathExtension)
        
        attributedText.addAttributes(options, range: NSMakeRange(0, selectedText.length))
        
        if (!editArea.isEditable) {
            return false
        }
        
        switch keyCode {
        case 11: // cmd-b
            if (!currentNote.isRTF()) {
                attributedText.mutableString.setString("**" + attributedText.string + "**")
            } else {
                editArea.textStorage?.applyFontTraits(NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(NSFontBoldTrait)), range: range)
            }
            break
        case 34:
            // control-shift-i
            if (!currentNote.isRTF() && modifier == 393475) {
                attributedText.mutableString.setString("![](" + attributedText.string + ")")
                break
            }
        
            // cmd-i
            if (!currentNote.isRTF()) {
                attributedText.mutableString.setString("_" + attributedText.string + "_")
            } else {
                editArea.textStorage?.applyFontTraits(NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(NSFontItalicTrait)), range: range)
            }
            break
        case 32: // cmd-u
            if (currentNote.isRTF()) {
                attributedText.addAttribute(NSUnderlineStyleAttributeName, value: NSUnderlineStyle.styleSingle.rawValue, range: NSMakeRange(0, selectedText.length))
            }
            break
        case 16: // cmd-y
            if (currentNote.isRTF()) {
                attributedText.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, selectedText.length))
            } else {
                attributedText.mutableString.setString("~~" + attributedText.string + "~~")
            }
        case (18...23): // cmd-1/6 (headers 1/6)
            if (!currentNote.isRTF()) {
                var string = ""
                var offset = 2
                
                for index in [18,19,20,21,23,22] {
                    string = string + "#"
                    if keyCode == index {
                        break
                    }
                    offset = offset + 1
                }
                
                attributedText.mutableString.setString(string + " " + attributedText.string)
            }
            break
        case 38: // control-shift-j (link)
            if (!currentNote.isRTF() && modifier == 393475) {
                attributedText.mutableString.setString("[](" + attributedText.string + ")")
            }
        default:
            return false
        }
        
        if (![11, 34].contains(keyCode) || !currentNote.isRTF() || modifier == 393475) {
            editArea.textStorage!.replaceCharacters(in: range, with: attributedText)
        }
        
        return save(note: currentNote)
    }

    @IBAction func editorBold(_ sender: Any) {
        formatter(keyCode: 11)
    }
    
    @IBAction func editorItalic(_ sender: Any) {
        formatter(keyCode: 34)
    }
    
    @IBAction func editorStrike(_ sender: Any) {
        formatter(keyCode: 16)
    }
    
    @IBAction func editorUnderline(_ sender: Any) {
        formatter(keyCode: 32)
    }
    
    @IBAction func editorHeader1(_ sender: Any) {
        formatter(keyCode: 18)
    }
    
    @IBAction func editorHeader2(_ sender: Any) {
        formatter(keyCode: 19)
    }
    
    @IBAction func editorHeader3(_ sender: Any) {
        formatter(keyCode: 20)
    }
    
    @IBAction func editorHeader4(_ sender: Any) {
        formatter(keyCode: 21)
    }
    
    @IBAction func editorHeader5(_ sender: Any) {
        formatter(keyCode: 23)
    }
    
    @IBAction func editorHeader6(_ sender: Any) {
        formatter(keyCode: 22)
    }
    
    @IBAction func editorImage(_ sender: Any) {
        formatter(keyCode: 34, modifier: 393475)
    }
    
    @IBAction func editorLink(_ sender: Any) {
        formatter(keyCode: 37, modifier: 393475)
    }
    
}
