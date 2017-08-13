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
        
        let fontName = UserDefaultsManagement.fontName
        date.font = NSFont(name: fontName, size: 10)
        preview.font = NSFont(name: fontName, size: 11)
        
        name.sizeToFit()
        
        if (UserDefaultsManagement.horizontalOrientation) {
            applyHorizontalConstrains()
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
        let dateTop = date.topAnchor.constraint(equalTo: self.topAnchor, constant: 4)
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
    override var backgroundStyle: NSBackgroundStyle {
        set {
            if let rowView = self.superview as? NSTableRowView {
                super.backgroundStyle = rowView.isSelected ? NSBackgroundStyle.dark : NSBackgroundStyle.light
            }
            self.udpateSelectionHighlight()
        }
        get {
            return super.backgroundStyle;
        }
    }
    
    func udpateSelectionHighlight() {
        if ( self.backgroundStyle == NSBackgroundStyle.dark ) {
            preview.textColor = NSColor.white
            date.textColor = NSColor.white
        } else {
            let lightGray = NSColor(deviceRed: 0.6, green: 0.6, blue: 0.6, alpha: 1)
            preview.textColor = lightGray
            date.textColor = lightGray
        }
    }
}
