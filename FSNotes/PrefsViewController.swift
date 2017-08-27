//
//  PrefsViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/4/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import MASShortcut

class PrefsViewController: NSViewController {

    @IBOutlet var previewCheckbox: NSButton!
    @IBOutlet var storageField: NSTextField!
    @IBOutlet var externalEditorApp: NSTextField!
    @IBOutlet weak var noteFont: NSPopUpButton!
    
    @IBOutlet weak var horizontalRadio: NSButton!
    @IBOutlet weak var verticalRadio: NSButton!
    
    let controller = NSApplication.shared().windows.first?.contentViewController as? ViewController
    
    @IBAction func changePreview(_ sender: Any) {
        if (sender as AnyObject).state == NSOffState {
            UserDefaultsManagement.hidePreview = false
        } else {
            UserDefaultsManagement.hidePreview = true
        }
        restart()
    }
    
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
    
    @IBAction func externalEditor(_ sender: Any) {
        UserDefaultsManagement.externalEditor = externalEditorApp.stringValue
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
    
    @IBOutlet weak var fontPreview: NSTextField!

    var fontPanelOpen: Bool = false
    
    @IBAction func setFont(_ sender: NSButton) {
        let fontManager = NSFontManager.shared()
        if UserDefaultsManagement.noteFont != nil {
            fontManager.setSelectedFont(UserDefaultsManagement.noteFont!, isMultiple: false)
        }
        
        fontManager.orderFrontFontPanel(self)
        fontPanelOpen = true
    }
    
    // changeFont is sent by the Font Panel.
    override func changeFont(_ sender: Any?) {
        let fontManager = NSFontManager.shared()
        let newFont = fontManager.convert(UserDefaultsManagement.noteFont!)
        UserDefaultsManagement.noteFont = newFont
        
        controller?.editArea.font = UserDefaultsManagement.noteFont
        setFontPreview()
    }

    func setFontPreview() {
        fontPreview.font = NSFont(name: UserDefaultsManagement.fontName, size: 13)
        fontPreview.stringValue = "\(UserDefaultsManagement.fontName) \(UserDefaultsManagement.fontSize)pt"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setFontPreview()
        initGlobalShortcuts()
    }
    
    override func viewDidAppear() {
        self.view.window!.title = "Preferences"
        
        let storageUrl = UserDefaults.standard.object(forKey: "storageUrl")
        if (storageUrl != nil) {
            storageField.stringValue = storageUrl as! String
        }
                
        externalEditorApp.stringValue = UserDefaultsManagement.externalEditor
        
        if (UserDefaultsManagement.horizontalOrientation) {
            horizontalRadio.cell?.state = 1
        } else {
            verticalRadio.cell?.state = 1
        }
        
        fileExtensionOutlet.stringValue = UserDefaultsManagement.storageExtension
        
        if (!UserDefaultsManagement.hidePreview) {
            previewCheckbox.state = NSOffState
        }
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
    
    @IBOutlet var newNoteshortcutView: MASShortcutView!
    @IBOutlet var searchNotesShortcut: MASShortcutView!
    
    func initGlobalShortcuts() {
        newNoteshortcutView.shortcutValue = UserDefaultsManagement.newNoteShortcut
        searchNotesShortcut.shortcutValue = UserDefaultsManagement.searchNoteShortcut
        
        newNoteshortcutView.shortcutValueChange = { (sender) in
            if ((self.newNoteshortcutView.shortcutValue) != nil) {
                let keyCode = self.newNoteshortcutView.shortcutValue.keyCode
                let modifierFlags = self.newNoteshortcutView.shortcutValue.modifierFlags
                
                UserDefaultsManagement.newNoteShortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
                
                MASShortcutMonitor.shared().register(self.newNoteshortcutView.shortcutValue, withAction: {
                    self.controller?.makeNoteShortcut()
                })
            } else {
                UserDefaultsManagement.newNoteShortcut = MASShortcut(keyCode: 45, modifierFlags: 917504)
            }
        }
        
        searchNotesShortcut.shortcutValueChange = { (sender) in
            
            if ((self.searchNotesShortcut.shortcutValue) != nil) {
                let keyCode = self.searchNotesShortcut.shortcutValue.keyCode
                let modifierFlags = self.searchNotesShortcut.shortcutValue.modifierFlags
                                print(keyCode)
                
                UserDefaultsManagement.searchNoteShortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
                
                MASShortcutMonitor.shared().register(self.searchNotesShortcut.shortcutValue, withAction: {
                    self.controller?.searchShortcut()
                })
            } else {
                UserDefaultsManagement.searchNoteShortcut = MASShortcut(keyCode: 37, modifierFlags: 917504)
            }
        }
    }
}
