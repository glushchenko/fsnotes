//
//  NoteCellView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/31/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class NoteCellView: NSTableCellView {

    @IBOutlet var name: NSTextField!
    @IBOutlet var preview: NSTextField!
    @IBOutlet var date: NSTextField!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
                
        date.font = NSFont(name: "Source Code Pro", size: 10)
        let font = NSFont(name: "Source Code Pro", size: 11)
        preview.font = font
        
        name.sizeToFit()
        
        if (UserDefaults.standard.object(forKey: "isUseHorizontalMode") != nil) {
            if (UserDefaults.standard.object(forKey: "isUseHorizontalMode") as! Bool) {
                applyHorizontalConstrains()
            } else {
                applyVerticalConstrainst()
            }
        } else {
            applyVerticalConstrainst()
        }
    }
    
    func applyVerticalConstrainst() {
    
        preview.translatesAutoresizingMaskIntoConstraints = false
        date.translatesAutoresizingMaskIntoConstraints = false
        name.translatesAutoresizingMaskIntoConstraints = false
        
        let previewTop = preview.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 3)
        let previewLeft = preview.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 5)
        let dateRight = date.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -5)
        let dateTop = date.topAnchor.constraint(equalTo: self.topAnchor, constant: 3)
        let nameRight = name.rightAnchor.constraint(equalTo: date.leftAnchor, constant: -8)
        let nameLeft = name.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 5)
        let nameTop = name.topAnchor.constraint(equalTo: self.topAnchor, constant: 5)

        date.sizeToFit()
        
        NSLayoutConstraint.activate([previewTop, previewLeft, dateRight, dateTop, nameLeft, nameRight, nameTop])
    }
    
    func applyHorizontalConstrains() {
        if (preview.stringValue.hasPrefix(" – ") == false && preview.stringValue.characters.count > 0) {
            self.preview.stringValue = " – " + preview.stringValue.replacingOccurrences(of: "\n", with: " ")
        }
        
        preview.translatesAutoresizingMaskIntoConstraints = false
        date.translatesAutoresizingMaskIntoConstraints = false
        
        let previewTop = preview.topAnchor.constraint(equalTo: self.topAnchor, constant: 2)
        let previewLeft = preview.leftAnchor.constraint(equalTo: name.rightAnchor, constant: 0)
        let dateRight = date.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -5)
        let dateTop = date.topAnchor.constraint(equalTo: self.topAnchor, constant: 3)
        let previewRight = preview.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -65)
        NSLayoutConstraint.activate([previewTop, previewLeft, dateRight, dateTop, previewRight])
    }
    
    
    // This NoteCellView has multiple contained views; this method changes
    // these views' color when the cell is selected.
    override var backgroundStyle: NSView.BackgroundStyle {
        set {
            super.backgroundStyle = newValue
            self.udpateSelectionHighlight()
        }
        get {
            return super.backgroundStyle;
        }
    }
    
    func udpateSelectionHighlight() {
        if ( self.backgroundStyle == NSView.BackgroundStyle.dark ) {
            preview.textColor = NSColor.white
            date.textColor = NSColor.white
        } else if( self.backgroundStyle == NSView.BackgroundStyle.light ) {
            let lightGray = NSColor(deviceRed: 0.6, green: 0.6, blue: 0.6, alpha: 1)
            preview.textColor = lightGray
            date.textColor = lightGray
        }
    }
}
