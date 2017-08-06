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
    
    //let controller = NSApplication.shared().windows.first?.contentViewController as? ViewController
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
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
        let previewTop = preview.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 10)
        let previewLeft = preview.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 5)
        NSLayoutConstraint.activate([previewTop, previewLeft])
    }
    
    func applyHorizontalConstrains() {
        if (preview.stringValue.hasPrefix(" – ") == false && preview.stringValue.characters.count > 0) {
            self.preview.stringValue = " – " + preview.stringValue.replacingOccurrences(of: "\n", with: " ")
        }
        
        preview.translatesAutoresizingMaskIntoConstraints = false
        let previewTop = preview.topAnchor.constraint(equalTo: self.topAnchor, constant: 2)
        let previewLeft = preview.leftAnchor.constraint(equalTo: name.rightAnchor, constant: 0)
        NSLayoutConstraint.activate([previewTop, previewLeft])
    }
}
