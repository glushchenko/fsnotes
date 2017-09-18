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
    @IBOutlet var pin: NSImageView!
    
    let labelColor = NSColor(deviceRed: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let fontName = UserDefaultsManagement.fontName
        date.font = NSFont(name: fontName, size: 10)
        renderPin()
        
        if (UserDefaultsManagement.horizontalOrientation) {
            applyHorizontalConstrains()
            return
        }
        
        if (!UserDefaultsManagement.hidePreview) {
            pin.frame.origin.y = 26
        }
        
        applyPreviewStyle(labelColor)
        applyVerticalConstrainst()
    }
    
    func applyPreviewStyle(_ color: NSColor) {
        let string = preview.stringValue
        
        let fontName = UserDefaultsManagement.fontName
        let font = NSFont(name: fontName, size: 11)!
        let textColor = color
        
        let textParagraph = NSMutableParagraphStyle()
            textParagraph.lineSpacing = 1
            textParagraph.maximumLineHeight = 12.0
        
        let attribs = [
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: textColor,
            NSParagraphStyleAttributeName: textParagraph
        ]
        
        preview.attributedStringValue = NSAttributedString.init(string: string, attributes: attribs)
        preview.maximumNumberOfLines = 2
    }
    
    func applyVerticalConstrainst() {
        preview.translatesAutoresizingMaskIntoConstraints = false
        date.translatesAutoresizingMaskIntoConstraints = false
        name.translatesAutoresizingMaskIntoConstraints = false
        pin.translatesAutoresizingMaskIntoConstraints = true
        
        let previewTop = preview.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 4)
        let previewLeft = preview.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 5)
        let previewRight = preview.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -3)
        let dateRight = date.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -5)
        let dateTop = date.topAnchor.constraint(equalTo: self.topAnchor, constant: 1)
        let nameRight = name.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -60)
        let nameTop = name.topAnchor.constraint(equalTo: self.topAnchor, constant: 2)
        let nameLeft = name.leftAnchor.constraint(equalTo: pin.rightAnchor, constant: 3)
        
        NSLayoutConstraint.activate([previewTop, previewLeft, previewRight, dateRight, dateTop, nameLeft, nameRight, nameTop])
    }
    
    func applyHorizontalConstrains() {
        preview.translatesAutoresizingMaskIntoConstraints = false
        date.translatesAutoresizingMaskIntoConstraints = false
        name.translatesAutoresizingMaskIntoConstraints = false
        
        preview.isHidden =  true
        
        let dateRight = date.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -10)
        let dateTop = date.topAnchor.constraint(equalTo: self.topAnchor, constant: 3)
        let nameLeft = name.leftAnchor.constraint(equalTo: pin.rightAnchor, constant: 5)
        let nameRight = name.rightAnchor.constraint(equalTo: date.leftAnchor, constant: -7)
        
        NSLayoutConstraint.activate([dateRight, dateTop,  nameLeft, nameRight])
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
            applyPreviewStyle(NSColor.white)
            date.textColor = NSColor.white
        } else {
            
            let lightGray = NSColor(deviceRed: 0.6, green: 0.6, blue: 0.6, alpha: 1)
            applyPreviewStyle(lightGray)
            date.textColor = lightGray
        }
    }
    
    func renderPin() {
        pin.isHidden = !(objectValue as! Note).isPinned
    }
}
