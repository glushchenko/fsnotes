//
//  PrefsViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/4/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PrefsViewController: NSViewController {

    @IBOutlet var storageField: NSTextField!
    @IBOutlet var externalEditorApp: NSTextField!
    @IBOutlet var previewApp: NSTextField!
    @IBOutlet weak var noteFont: NSPopUpButton!
    
    @IBOutlet weak var horizontalRadio: NSButton!
    @IBOutlet weak var verticalRadio: NSButton!
    
    let controller = NSApplication.shared().windows.first?.contentViewController as? ViewController
    
    @IBAction func selectDefaultFileStorage(_ sender: Any) {
        
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
       
        openPanel.begin { (result) -> Void in
            if result == NSFileHandlingPanelOKButton {
                let bookmark = SandboxBookmark()
                let url = openPanel.url
                
                bookmark.store(url: url!)
                bookmark.save()
                
                UserDefaults.standard.set(openPanel.url, forKey: "storageUrl")
                    
                self.restart()
            }
        }
    }
    
    @IBAction func previewApp(_ sender: Any) {
        UserDefaults.standard.set(previewApp.stringValue, forKey: "previewApp")
    }
    
    @IBAction func extrenalEditor(_ sender: Any) {
        UserDefaults.standard.set(externalEditorApp.stringValue, forKey: "externalEditorApp")
    }
    
    @IBAction func verticalOrientation(_ sender: Any) {
        UserDefaultsManagement.horizontalOrientation = false
        
        horizontalRadio.cell?.state = 0
        controller?.splitView.isVertical = true
        controller?.splitView.setPosition(215, ofDividerAt: 0)
        controller?.notesTableView.rowHeight = 63
        
        restart()
    }
    
    @IBAction func horizontalOrientation(_ sender: Any) {
        UserDefaultsManagement.horizontalOrientation = true
        
        verticalRadio.cell?.state = 0
        controller?.splitView.isVertical = false
        controller?.splitView.setPosition(215, ofDividerAt: 0)
        controller?.notesTableView.rowHeight = 30
        
        restart()
    }
    
    @IBAction func changedFont(_ sender: Any) {
        guard let selectedNoteFont = noteFont.selectedItem?.title
            else {return}
        
        UserDefaultsManagement.fontName = selectedNoteFont
        controller?.editArea.font = NSFont(name: selectedNoteFont, size: 13)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear() {
        self.view.window!.title = "Preferences"
        
        let storageUrl = UserDefaults.standard.object(forKey: "storageUrl")
        if (storageUrl != nil) {
            storageField.stringValue = storageUrl as! String
        }
        
        let previewAppKey = UserDefaults.standard.object(forKey: "previewApp")
        if (previewAppKey != nil) {
            previewApp.stringValue = previewAppKey as! String
        }
        
        let externalEditorAppKey = UserDefaults.standard.object(forKey: "externalEditorApp")
        if (externalEditorAppKey != nil) {
            externalEditorApp.stringValue = externalEditorAppKey as! String
        }
        
        if (UserDefaultsManagement.horizontalOrientation) {
            horizontalRadio.cell?.state = 1
        } else {
            verticalRadio.cell?.state = 1
        }
        
        fileExtensionOutlet.stringValue = (controller?.getDefaultFileExtension())!
        
        // populate fonts
        var availableFonts = NSFontManager.shared().availableFontFamilies
        if (availableFonts.contains(UserDefaultsManagement.DefaultFont) == false) {
            availableFonts.append(UserDefaultsManagement.DefaultFont)
        }
        noteFont.addItems(withTitles: availableFonts)
        noteFont.selectItem(withTitle: UserDefaultsManagement.fontName)
    }
    
    func restart() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        exit(0)
    }
    
    @IBOutlet var fileExtensionOutlet: NSTextField!
    @IBAction func fileExtensionAction(_ sender: NSTextField) {
        let value = sender.stringValue
        UserDefaults.standard.set(value, forKey: "fileExtension")
    }
    
}
