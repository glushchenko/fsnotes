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
        } else {
            applyVerticalConstrainst()
        }
        
        udpateSelectionHighlight()
    }
    
    func isFullVertical() -> Bool {
        return (!UserDefaultsManagement.hidePreview && !UserDefaultsManagement.horizontalOrientation)
    }
    
    func applyPreviewStyle(_ color: NSColor) {
        var maximumNumberOfLines = 1
        let heightDiff = self.frame.height - CGFloat(Float(UserDefaultsManagement.minTableRowHeight))
    
        guard heightDiff > 0 else {
            applyPreviewAttributes()
            return
        }
        
        // fix full vertical view pin position
        if (isFullVertical()) {
            pin.frame.origin.y = 13 + heightDiff
        }
    
        // vertically align
        if let font = preview.font {
            var addLines = 0
            let lineHeight = font.height - 2
            
            if (isFullVertical() && heightDiff >= lineHeight) {
                addLines = Int(heightDiff/lineHeight)
                maximumNumberOfLines += addLines
            }
            
            let diff = (Float(heightDiff) - Float(addLines) * Float(lineHeight)) / 2
            self.frame.origin.y = CGFloat(Int(diff) + addLines)
        }
        
        // apply font and max lines numbers
        applyPreviewAttributes(maximumNumberOfLines)
    }
    
    func applyPreviewAttributes(_ maximumNumberOfLines: Int = 1) {
        let string = preview.stringValue
        let fontName = UserDefaultsManagement.fontName
        let font = NSFont(name: fontName, size: 11)!
        let textColor = labelColor
        
        let textParagraph = NSMutableParagraphStyle()
        textParagraph.lineSpacing = 1
        textParagraph.maximumLineHeight = 12.0
        
        let attribs = [
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: textColor,
            NSParagraphStyleAttributeName: textParagraph
        ]
        
        preview.attributedStringValue = NSAttributedString.init(string: string, attributes: attribs)
        preview.maximumNumberOfLines = maximumNumberOfLines
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
        let nameTop = name.topAnchor.constraint(equalTo: self.topAnchor, constant: 3)
        let nameLeft = name.leftAnchor.constraint(equalTo: pin.rightAnchor, constant: 5)
        let nameRight = name.rightAnchor.constraint(equalTo: date.leftAnchor, constant: -7)
        
        NSLayoutConstraint.activate([dateRight, dateTop,  nameLeft, nameRight, nameTop])
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
            applyPreviewStyle(labelColor)
            date.textColor = labelColor
        }
    }
    
    func renderPin() {
        pin.isHidden = !(objectValue as! Note).isPinned
    }
}
