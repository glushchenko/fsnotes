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
                if (preview.stringValue.hasPrefix(" – ") == false && preview.stringValue.characters.count > 0) {
                    self.preview.stringValue = " – " + preview.stringValue.replacingOccurrences(of: "\n", with: " ")
                }
                
                self.preview.translatesAutoresizingMaskIntoConstraints = false
                
                let nameTop = name.topAnchor.constraint(equalTo: self.topAnchor, constant: 10)
                let nameLeft = name.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 120)
                let nameRight = name.rightAnchor.constraint(equalTo: self.preview.leftAnchor, constant: 0)
                let previewTop = preview.topAnchor.constraint(equalTo: self.topAnchor, constant: 2)
                
                NSLayoutConstraint.activate([nameTop, nameLeft, nameRight, previewTop])
            } else {
                let nameTop = name.topAnchor.constraint(equalTo: self.topAnchor)
                let nameLeft = name.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 2)
                let previewTop = preview.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 2)
                let previewBottom = preview.bottomAnchor.constraint(equalTo: self.bottomAnchor)
                
                self.preview.translatesAutoresizingMaskIntoConstraints = false
                
                NSLayoutConstraint.activate([nameTop, nameLeft, previewTop, previewBottom])
            }
        }
    }
}
