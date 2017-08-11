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
    
    func fill(note: Note) {
        let url = note.url!
        var attributedString: NSAttributedString
 
        if (url.pathExtension == Note.Extensions.RichTextFormat) {
            attributedString = getRtfAttributedString(url: url)
        } else {
            attributedString = getPlainTextAttributedString(url: url)
        }
        
        self.textStorage?.setAttributedString(attributedString)
        self.textStorage?.font = NSFont(name: UserDefaultsManagement.fontName, size: 13.0)
        
    }

    func getRtfAttributedString(url: URL) -> NSAttributedString {
        var attributedString =  NSAttributedString()
        
        do {
            attributedString = try NSAttributedString(url: url, options: [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType], documentAttributes: nil)
        } catch {
            self.print("No RTF content found!")
            
            return getPlainTextAttributedString(url: url)
        }
        
        return attributedString
    }
    
    func getPlainTextAttributedString(url: URL) -> NSAttributedString {
        var attributedString =  NSAttributedString()
        
        do {
            attributedString = try NSAttributedString(url: url, options: [NSDocumentTypeDocumentAttribute: NSPlainTextDocumentType], documentAttributes: nil)
        } catch {
            self.print("No plain text content found!")
        }
        
        return attributedString
    }
}
