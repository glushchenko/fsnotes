//
//  PrefsViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/4/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PrefsViewController: NSViewController {

    @IBOutlet weak var horizontalRadio: NSButton!
    @IBOutlet weak var verticalRadio: NSButton!
    
    let controller = NSApplication.shared().windows.first?.contentViewController as? ViewController
    
    @IBAction func verticalOrientation(_ sender: Any) {
        horizontalRadio.cell?.state = 0
        UserDefaults.standard.set(false, forKey: "isUseHorizontalMode")
        
        controller?.splitView.isVertical = true
        controller?.splitView.setPosition(215, ofDividerAt: 0)
        controller?.notesTableView.rowHeight = 90
    }
    
    @IBAction func horizontalOrientation(_ sender: Any) {
        verticalRadio.cell?.state = 0
        UserDefaults.standard.set(true, forKey: "isUseHorizontalMode")
        
        controller?.splitView.isVertical = false
        controller?.splitView.setPosition(215, ofDividerAt: 0)
        controller?.notesTableView.rowHeight = 30
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear() {
        self.view.window!.title = "Preferences"
        
        if (UserDefaults.standard.object(forKey: "isUseHorizontalMode") != nil) {
            let isUseHorizontalMode = UserDefaults.standard.object(forKey: "isUseHorizontalMode") as! Bool
            
            if (isUseHorizontalMode) {
                horizontalRadio.cell?.state = 1
            } else {
                verticalRadio.cell?.state = 1
            }
        }
    }
    
}
