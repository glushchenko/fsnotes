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
    
    var currentNote = Note()
        
    func fill(note: Note) {
        self.currentNote = note
        
        self.isEditable = true
        self.isRichText = note.isRTF()

        let attrString = createAttributedString(note: note)
        self.textStorage?.setAttributedString(attrString)
        self.textStorage?.font = UserDefaultsManagement.noteFont
        
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
    
    override func keyDown(with event: NSEvent) {
        if (event.modifierFlags.contains(.command)) {
            let range = selectedRange()
            let text = textStorage!.string as NSString
            let selectedText = text.substring(with: range) as NSString
            let attributedText = NSMutableAttributedString(string: selectedText as String)
            let options = DocumentAttributes.getDocumentAttributes(fileExtension: currentNote.url.pathExtension)
            
            attributedText.addAttributes(options, range: NSMakeRange(0, selectedText.length))
            
            switch event.keyCode {
            case 11: // cmd - b
                if (!currentNote.isRTF()) {
                    attributedText.mutableString.setString("**" + attributedText.string + "**")
                }
                break
            case 34: // cmd - i
                if (!currentNote.isRTF()) {
                    attributedText.mutableString.setString("_" + attributedText.string + "_")
                }
                break
            case 32: // cmd - u
                if (currentNote.isRTF()) {
                    attributedText.addAttribute(NSUnderlineStyleAttributeName, value: NSUnderlineStyle.styleSingle.rawValue, range: NSMakeRange(0, selectedText.length))
                }
                break
            default: break
            }
            
            textStorage!.replaceCharacters(in: range, with: attributedText)
            save(note: currentNote)
        }
        
        super.keyDown(with: event)
    }
    
    func formatRTF() {
        
    }
}
