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
    @IBOutlet var cloudKitCheckbox: NSButton!
    @IBOutlet var tabView: NSTabView!
    @IBOutlet var tabViewSync: NSTabViewItem!
    @IBOutlet var hidePreview: NSButtonCell!
    @IBOutlet var fileExtensionOutlet: NSTextField!
    @IBOutlet var newNoteshortcutView: MASShortcutView!
    @IBOutlet var searchNotesShortcut: MASShortcutView!
    @IBOutlet var lastSyncOutlet: NSTextField!
    @IBOutlet weak var fontPreview: NSTextField!
    @IBOutlet weak var cloudStatus: NSTextField!
    @IBOutlet weak var syncedTotal: NSTextField!
    @IBOutlet weak var syncProgress: NSProgressIndicator!
    @IBOutlet weak var codeBlockHighlight: NSButtonCell!
    @IBOutlet weak var markdownCodeTheme: NSPopUpButton!
    @IBOutlet weak var liveImagesPreview: NSButton!
    
    let viewController = NSApplication.shared.windows.first!.contentViewController as! ViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setFontPreview()
        initShortcuts()
    }
    
    override func viewDidAppear() {
        syncProgress.isHidden = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(onCountChange(notification:)), name: NSNotification.Name(rawValue: "onCountChange"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onStartSync(notification:)), name: NSNotification.Name(rawValue: "onStartSync"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onFinishSync(notification:)), name: NSNotification.Name(rawValue: "onFinishSync"), object: nil)
        
        self.view.window!.title = "Preferences"
        
        externalEditorApp.stringValue = UserDefaultsManagement.externalEditor
        
        if (UserDefaultsManagement.horizontalOrientation) {
            horizontalRadio.cell?.state = NSControl.StateValue(rawValue: 1)
        } else {
            verticalRadio.cell?.state = NSControl.StateValue(rawValue: 1)
        }
        
        hidePreview.state = UserDefaultsManagement.hidePreview ? NSControl.StateValue.on : NSControl.StateValue.off
        
        fileExtensionOutlet.stringValue = UserDefaultsManagement.storageExtension
        
        cloudKitCheckbox.state =  UserDefaultsManagement.cloudKitSync ? NSControl.StateValue.on : NSControl.StateValue.off
        
        codeBlockHighlight.state = UserDefaultsManagement.codeBlockHighlight ? NSControl.StateValue.on : NSControl.StateValue.off
        
        liveImagesPreview.state = UserDefaultsManagement.liveImagesPreview ? NSControl.StateValue.on : NSControl.StateValue.off
        
        markdownCodeTheme.selectItem(withTitle: UserDefaultsManagement.codeTheme)
        
        #if CLOUDKIT
            checkCloudStatus()
        #else
            tabView.removeTabViewItem(tabViewSync)
        #endif
        
        loadLastSync()
        
        storageTableView.list = CoreDataManager.instance.fetchStorageList()
        storageTableView.reloadData()
        
        NotificationsController.syncProgress()
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
    
    @IBAction func cloudKitSync(_ sender: AnyObject) {
        let state = (sender as! NSButton).state
        UserDefaultsManagement.cloudKitSync = !(state == NSControl.StateValue.off)

        checkCloudStatus()
        
        if state == NSControl.StateValue.on {
            CloudKitManager.instance.sync()
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
                    
                    if let selected = self.storageTableView.getSelected() {
                        storage = selected
                    } else {
                        let context = CoreDataManager.instance.context
                        storage = StorageItem(context: context)
                    }
                    
                    storage.path = url.absoluteString
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
    }
    
    @IBAction func horizontalOrientation(_ sender: Any) {
        UserDefaultsManagement.horizontalOrientation = true
        
        verticalRadio.cell?.state = NSControl.StateValue(rawValue: 0)
        controller?.splitView.isVertical = false
        controller?.splitView.setPosition(215, ofDividerAt: 0)
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
        let controller = NSApplication.shared.windows.first?.contentViewController as? ViewController
        controller?.editArea.setEditorTextColor(sender.color)
    }
    
    @IBAction func setBgColor(_ sender: NSColorWell) {
        let controller = NSApplication.shared.windows.first?.contentViewController as? ViewController
        controller?.editArea.backgroundColor = sender.color
    }
    
    @IBAction func changeCellSpacing(_ sender: NSSlider) {
        controller?.setTableRowHeight()
    }
    
    @IBAction func changePreview(_ sender: Any) {
        UserDefaultsManagement.hidePreview = ((sender as AnyObject).state == NSControl.StateValue.on)
        controller?.notesTableView.reloadData()
    }
    
    @IBAction func resetCloudKitData(_ sender: Any) {
        let alert = NSAlert.init()
        alert.messageText = "Are you sure you want remove data from iCloud?"
        alert.informativeText = "This action cannot be undone."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: self.view.window!) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                CloudKitManager.instance.flush()
            }
        }
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
            controller?.reloadView(note: note)
        }
        
        controller?.notesTableView.reloadData()
        setFontPreview()
    }

    func setFontPreview() {
        fontPreview.font = NSFont(name: UserDefaultsManagement.fontName, size: 13)
        fontPreview.stringValue = "\(UserDefaultsManagement.fontName) \(UserDefaultsManagement.fontSize)pt"
    }
    
    func loadLastSync() {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [
            .withYear,
            .withMonth,
            .withDay,
            .withTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withSpaceBetweenDateAndTime
        ]
        dateFormatter.timeZone = NSTimeZone.local
        
        if let lastSync = UserDefaultsManagement.lastSync {
            lastSyncOutlet.stringValue = dateFormatter.string(from: lastSync)
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
    
    func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutableRawPointer) {
        Swift.print("keyPath")
    }
    
    func checkCloudStatus() {
        CloudKitManager.instance.container.accountStatus { (accountStatus, error) in
            var result: String
            
            switch accountStatus {
            case .available:
                result = "iCloud available"
                break
            case .couldNotDetermine, .noAccount, .restricted:
                result = "iCloud not available"
                self.cloudKitCheckbox.state = NSControl.StateValue.off
                break
            }
            
            DispatchQueue.main.async {
                self.cloudStatus.stringValue = result
            }
        }
    }
    
    @objc func onCountChange(notification: Notification) {
        DispatchQueue.main.async {
            self.syncedTotal.stringValue = notification.userInfo?.first?.value as! String
        }
    }
    
    @objc func onStartSync(notification: Notification) {
        syncedTotal.isHidden = true
        syncProgress.isHidden = false
        syncProgress.startAnimation("sync")
    }
    
    @IBAction func markdownCodeThemeAction(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else {
            return
        }
        
        UserDefaultsManagement.codeTheme = item.title
        
        if let note = EditTextView.note {
            NotesTextProcessor.hl = nil
            note.markdownCache()
        }
    }
    
    @objc func onFinishSync(notification: Notification) {
        syncedTotal.isHidden = false
        syncProgress.isHidden = true
        syncProgress.stopAnimation("sync")
    }
}
