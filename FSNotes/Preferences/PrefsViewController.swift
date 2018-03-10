//
//  PrefsViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/4/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import MASShortcut
import CoreData

class PrefsViewController: NSViewController {

    @IBOutlet weak var storageTableView: StorageTableView!
    @IBOutlet var externalEditorApp: NSTextField!
    @IBOutlet weak var horizontalRadio: NSButton!
    @IBOutlet weak var verticalRadio: NSButton!
    @IBOutlet var tabView: NSTabView!
    @IBOutlet var hidePreview: NSButtonCell!
    @IBOutlet var fileExtensionOutlet: NSTextField!
    @IBOutlet var newNoteshortcutView: MASShortcutView!
    @IBOutlet var searchNotesShortcut: MASShortcutView!
    @IBOutlet weak var fontPreview: NSTextField!
    @IBOutlet weak var codeBlockHighlight: NSButtonCell!
    @IBOutlet weak var markdownCodeTheme: NSPopUpButton!
    @IBOutlet weak var liveImagesPreview: NSButton!
    @IBOutlet weak var cellSpacing: NSSlider!
    @IBOutlet weak var noteFontColor: NSColorWell!
    @IBOutlet weak var backgroundColor: NSColorWell!
    @IBOutlet weak var inEditorFocus: NSButton!
    
    let viewController = NSApplication.shared.windows.first!.contentViewController as! ViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setFontPreview()
        initShortcuts()
    }
    
    override func viewDidAppear() {
        self.view.window!.title = "Preferences"
        
        externalEditorApp.stringValue = UserDefaultsManagement.externalEditor
        
        if (UserDefaultsManagement.horizontalOrientation) {
            horizontalRadio.cell?.state = NSControl.StateValue(rawValue: 1)
        } else {
            verticalRadio.cell?.state = NSControl.StateValue(rawValue: 1)
        }
        
        hidePreview.state = UserDefaultsManagement.hidePreview ? NSControl.StateValue.on : NSControl.StateValue.off
        
        fileExtensionOutlet.stringValue = UserDefaultsManagement.storageExtension
                
        codeBlockHighlight.state = UserDefaultsManagement.codeBlockHighlight ? NSControl.StateValue.on : NSControl.StateValue.off
        
        liveImagesPreview.state = UserDefaultsManagement.liveImagesPreview ? NSControl.StateValue.on : NSControl.StateValue.off
        
        inEditorFocus.state = UserDefaultsManagement.focusInEditorOnNoteSelect ? NSControl.StateValue.on : NSControl.StateValue.off
        
        markdownCodeTheme.selectItem(withTitle: UserDefaultsManagement.codeTheme)
        
        cellSpacing.doubleValue = Double(UserDefaultsManagement.cellSpacing)
        
        noteFontColor.color = UserDefaultsManagement.fontColor
        backgroundColor.color = UserDefaultsManagement.bgColor
        
        storageTableView.list = CoreDataManager.instance.fetchStorageList()
        storageTableView.reloadData()
    }
    
    @IBAction func liveImagesPreview(_ sender: NSButton) {
        UserDefaultsManagement.liveImagesPreview = (sender.state == NSControl.StateValue.on)
        
        controller?.refillEditArea()
    }
    
    @IBAction func codeBlockHighlight(_ sender: NSButton) {
        UserDefaultsManagement.codeBlockHighlight = (sender.state == NSControl.StateValue.on)
        
        restart()
    }
    
    @IBAction func fileExtensionAction(_ sender: NSTextField) {
        let value = sender.stringValue
        UserDefaults.standard.set(value, forKey: "fileExtension")
    }
    
    @IBAction func changeHideOnDeactivate(_ sender: NSButton) {
        // We don't need to set the user defaults value here as the checkbox is
        // bound to it. We do need to update each window's hideOnDeactivate.
        for window in NSApplication.shared.windows {
            window.hidesOnDeactivate = UserDefaultsManagement.hideOnDeactivate
        }
    }
    
    @IBAction func addStorage(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.canCreateDirectories = true
        
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                let bookmark = SandboxBookmark()
                let url = openPanel.url
                
                bookmark.load()
                bookmark.store(url: url!)
                bookmark.save()
                
                if let url = openPanel.url {
                    var storage: StorageItem
                    let selected = self.storageTableView.getSelected()
                    
                    if selected != nil {
                        storage = selected!
                    } else {
                        let context = CoreDataManager.instance.context
                        storage = StorageItem(context: context)
                    }
                    
                    storage.path = url.absoluteString
                    
                    // reset instantiated storage
                    if selected != nil && selected?.label == "general" {
                        CoreDataManager.instance.setDefaultStorage(storage: storage)
                        Storage.generalUrl = nil
                    }
                    
                    CoreDataManager.instance.save()
                    self.reloadStorage()
                }
            }
        }
    }
    
    @IBAction func removeStorage(_ sender: Any) {
        if let storage = storageTableView.getSelected(), storage.label != "general" {
            CoreDataManager.instance.remove(storage: storage)
            reloadStorage()
        }
    }
    
    @IBAction func externalEditor(_ sender: Any) {
        UserDefaultsManagement.externalEditor = externalEditorApp.stringValue
    }
    
    @IBAction func verticalOrientation(_ sender: Any) {
        UserDefaultsManagement.horizontalOrientation = false
        
        horizontalRadio.cell?.state = NSControl.StateValue(rawValue: 0)
        controller?.splitView.isVertical = true
        controller?.splitView.setPosition(215, ofDividerAt: 0)
        
        UserDefaultsManagement.cellSpacing = 38
        cellSpacing.doubleValue = Double(UserDefaultsManagement.cellSpacing)
        controller?.setTableRowHeight()
    }
    
    @IBAction func horizontalOrientation(_ sender: Any) {
        UserDefaultsManagement.horizontalOrientation = true
        
        verticalRadio.cell?.state = NSControl.StateValue(rawValue: 0)
        controller?.splitView.isVertical = false
        controller?.splitView.setPosition(145, ofDividerAt: 0)
        
        UserDefaultsManagement.cellSpacing = 12
        cellSpacing.doubleValue = Double(UserDefaultsManagement.cellSpacing)
        controller?.setTableRowHeight()
    }
    
    @IBAction func setFont(_ sender: NSButton) {
        let fontManager = NSFontManager.shared
        if UserDefaultsManagement.noteFont != nil {
            fontManager.setSelectedFont(UserDefaultsManagement.noteFont!, isMultiple: false)
        }
        
        fontManager.orderFrontFontPanel(self)
        fontPanelOpen = true
    }
    
    @IBAction func setFontColor(_ sender: NSColorWell) {
        UserDefaultsManagement.fontColor = sender.color
        controller?.editArea.setEditorTextColor(sender.color)
        
        if let note = EditTextView.note {
            note.markdownCache()
            controller?.refillEditArea()
        }
    }
    
    @IBAction func setBgColor(_ sender: NSColorWell) {
        let controller = NSApplication.shared.windows.first?.contentViewController as? ViewController
        
        UserDefaultsManagement.bgColor = sender.color
        
        controller?.editArea.backgroundColor = sender.color
    }
    
    @IBAction func changeCellSpacing(_ sender: NSSlider) {
        controller?.setTableRowHeight()
    }
    
    @IBAction func changePreview(_ sender: Any) {
        UserDefaultsManagement.hidePreview = ((sender as AnyObject).state == NSControl.StateValue.on)
        controller?.notesTableView.reloadData()
    }
    
    var fontPanelOpen: Bool = false
    let controller = NSApplication.shared.windows.first?.contentViewController as? ViewController
    
    // changeFont is sent by the Font Panel.
    override func changeFont(_ sender: Any?) {
        let fontManager = NSFontManager.shared
        let newFont = fontManager.convert(UserDefaultsManagement.noteFont!)
        UserDefaultsManagement.noteFont = newFont
        
        if let note = EditTextView.note {
            note.markdownCache()
            controller?.refillEditArea()
        }
        
        controller?.reloadView()
        setFontPreview()
    }

    func setFontPreview() {
        fontPreview.font = NSFont(name: UserDefaultsManagement.fontName, size: 13)
        fontPreview.stringValue = "\(UserDefaultsManagement.fontName) \(UserDefaultsManagement.fontSize)pt"
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
    
    func initShortcuts() {
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
                
                UserDefaultsManagement.searchNoteShortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
                
                MASShortcutMonitor.shared().register(self.searchNotesShortcut.shortcutValue, withAction: {
                    self.controller?.searchShortcut()
                })
            } else {
                UserDefaultsManagement.searchNoteShortcut = MASShortcut(keyCode: 37, modifierFlags: 917504)
            }
        }
    }
    
    func reloadStorage() {
        Storage.instance.loadDocuments()
        
        self.storageTableView.reload()
        self.viewController.updateTable(filter: "") {
            self.viewController.loadMoveMenu()
        }
    }
    
    @IBAction func markdownCodeThemeAction(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else {
            return
        }
        
        UserDefaultsManagement.codeTheme = item.title
        
        if let note = EditTextView.note {
            NotesTextProcessor.hl = nil
            note.markdownCache()
            controller?.refillEditArea()
        }
    }
    
    @IBAction func inEditorFocus(_ sender: NSButton) {
        UserDefaultsManagement.focusInEditorOnNoteSelect = (sender.state == .on)
    }
    
}
