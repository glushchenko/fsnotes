//
//  EditTextView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/11/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Down

class EditTextView: NSTextView {
    var downView: DownView?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
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
        let mainWindow = NSApplication.shared().windows.first
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
        if (event.modifierFlags.contains(.command) || event.modifierFlags.rawValue == 393475) {
            if (formatShortcut(keyCode: event.keyCode, modifier: event.modifierFlags.rawValue as UInt)) {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    func getSelectedNote() -> Note? {
        let mainWindow = NSApplication.shared().windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let note = viewController.notesTableView.getNoteFromSelectedRow()
        return note
    }
        
    func fill(note: Note) {
        self.isEditable = !UserDefaultsManagement.preview
        self.isRichText = note.isRTF()

        self.subviews.removeAll()
        
        if (!(getSelectedNote()?.isRTF())!) {
            if (UserDefaultsManagement.preview) {
                self.string = ""
                self.subviews.removeAll()
                
                let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
                let url = NSURL.fileURL(withPath: path!)
                let bundle = Bundle(url: url)
                
                do {
                    downView = try? DownView(frame: (self.superview?.bounds)!, markdownString: note.getPrettifiedContent(), templateBundle: bundle) {
                        self.addSubview(self.downView!)
                    }
                }
            } else {
                let attrString = createAttributedString(note: note)
                self.textStorage?.setAttributedString(attrString)
                self.textStorage?.font = UserDefaultsManagement.noteFont
            }
        } else {
            let attrString = createAttributedString(note: note)
            self.textStorage?.setAttributedString(attrString)
        }
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.emptyEditAreaImage.isHidden = true
    }
    
    func save(note: Note) -> Bool {
        let fileUrl = note.url
        let fileExtension = fileUrl?.pathExtension
        
        do {
            let range = NSRange(location: 0, length: (textStorage?.string.characters.count)!)
            let documentAttributes = DocumentAttributes.getDocumentAttributes(fileExtension: fileExtension!)
            let text = try textStorage?.fileWrapper(from: range, documentAttributes: documentAttributes)
            try text?.write(to: fileUrl!, options: FileWrapper.WritingOptions.atomic, originalContentsURL: nil)
           
            return true
        } catch let error {
            NSLog(error.localizedDescription)
        }
        
        return false
    }
    
    func clear() {
        textStorage?.mutableString.setString("")
        subviews.removeAll()
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
    
    func formatShortcut(keyCode: UInt16, modifier: UInt = 0) -> Bool {
        let mainWindow = NSApplication.shared().windows.first
        let viewController = mainWindow?.contentViewController as! ViewController
        let editArea = viewController.editArea!
        
        guard let currentNote = getSelectedNote() else {
            return false
        }
        
        if (!editArea.isEditable) {
            return false
        }

        let text = editArea.textStorage!.string as NSString
        let range = editArea.selectedRange()
        let selectedText = text.substring(with: range) as NSString
        let selectedRange = NSMakeRange(0, selectedText.length)
        
        let attributedSelected = editArea.attributedSubstring(forProposedRange: range, actualRange: nil)
        var attributedText = NSMutableAttributedString()
        
        if (attributedSelected == nil) {
            let options = DocumentAttributes.getDocumentAttributes(fileExtension: currentNote.url.pathExtension)
            attributedText.addAttributes(options, range: NSMakeRange(0, selectedText.length))
        } else {
            attributedText = NSMutableAttributedString(attributedString: attributedSelected!)
        }
        
        switch keyCode {
        case 11: // cmd-b
            if (!currentNote.isRTF()) {
                attributedText.mutableString.setString("**" + attributedText.string + "**")
            } else {
                if (selectedText.length > 0) {
                    let fontAttributes = attributedSelected?.fontAttributes(in: selectedRange)
                    let newFont = toggleBoldFont(font: fontAttributes!["NSFont"] as! NSFont)
                    attributedText.addAttribute("NSFont", value: newFont, range: selectedRange)
                }

                typingAttributes["NSFont"] = toggleBoldFont(font: typingAttributes["NSFont"] as! NSFont)
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
                if (selectedText.length > 0) {
                    let fontAttributes = attributedSelected?.fontAttributes(in: selectedRange)
                    let newFont = toggleItalicFont(font: fontAttributes!["NSFont"] as! NSFont)
                    attributedText.addAttribute("NSFont", value: newFont, range: selectedRange)
                }
                
                typingAttributes["NSFont"] = toggleItalicFont(font: typingAttributes["NSFont"] as! NSFont)
            }
            break
        case 32: // cmd-u
            if (currentNote.isRTF()) {
                if (selectedText.length > 0) {
                    attributedText.removeAttribute("NSUnderline", range: NSMakeRange(0, selectedText.length))
                }
                
                if (typingAttributes["NSUnderline"] == nil) {
                    attributedText.addAttribute(NSUnderlineStyleAttributeName, value: NSUnderlineStyle.styleSingle.rawValue, range: NSMakeRange(0, selectedText.length))
                    typingAttributes["NSUnderline"] = 1
                } else {
                    typingAttributes.removeValue(forKey: "NSUnderline")
                }
            }
            break
        case 16: // cmd-y
            if (currentNote.isRTF()) {
                if (selectedText.length > 0) {
                    attributedText.removeAttribute("NSStrikethrough", range: NSMakeRange(0, selectedText.length))
                }
                
                if (typingAttributes["NSStrikethrough"] == nil) {
                    attributedText.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, selectedText.length))
                    typingAttributes["NSStrikethrough"] = 2
                } else {
                    typingAttributes.removeValue(forKey: "NSStrikethrough")
                }
            } else {
                attributedText.mutableString.setString("~~" + attributedText.string + "~~")
            }
        case (18...23): // cmd-1/6 (headers 1/6)
            if (!currentNote.isRTF()) {
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
            if (!currentNote.isRTF() && modifier == 393475) {
                attributedText.mutableString.setString("[](" + attributedText.string + ")")
            }
            break
        default:
            return false
        }
        
        if (!UserDefaultsManagement.preview) {
            editArea.textStorage!.replaceCharacters(in: range, with: attributedText)
            
            if (currentNote.isRTF()) {
                editArea.setSelectedRange(range)
            }
        
            currentNote.save(editArea.textStorage!)
            return true
        }
        
        return false
    }
    
    func toggleBoldFont(font: NSFont) -> NSFont {
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
       
        return NSFontManager().font(withFamily: UserDefaultsManagement.noteFont.familyName!, traits: NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(mask)), weight: 0, size: CGFloat(UserDefaultsManagement.fontSize))!
    }
    
    func toggleItalicFont(font: NSFont) -> NSFont {
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
        
        return NSFontManager().font(withFamily: UserDefaultsManagement.noteFont.familyName!, traits: NSFontTraitMask(rawValue: NSFontTraitMask.RawValue(mask)), weight: 0, size: CGFloat(UserDefaultsManagement.fontSize))!
    }
    
    override func paste(_ sender: Any?) {
        super.pasteAsPlainText(nil)
    }
}
