//
//  PreferencesUserInterfaceViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 3/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class PreferencesUserInterfaceViewController: NSViewController {

    @IBOutlet weak var horizontalRadio: NSButton!
    @IBOutlet weak var verticalRadio: NSButton!
    @IBOutlet weak var cellSpacing: NSSlider!
    @IBOutlet weak var previewFontSize: NSPopUpButton!
    @IBOutlet weak var hideImagesPreview: NSButton!
    @IBOutlet weak var hidePreview: NSButton!
    @IBOutlet weak var hideDate: NSButton!
    @IBOutlet weak var firstLineAsTitle: NSButton!
    @IBOutlet weak var showDockIcon: NSButton!
    @IBOutlet weak var showInMenuBar: NSButton!

    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = NSSize(width: 550, height: 460)
    }

    override func viewDidAppear() {
        guard let window = self.view.window else { return }
        window.title = NSLocalizedString("Settings", comment: "")

        if (UserDefaultsManagement.horizontalOrientation) {
            horizontalRadio.cell?.state = NSControl.StateValue(rawValue: 1)
        } else {
            verticalRadio.cell?.state = NSControl.StateValue(rawValue: 1)
        }

        hidePreview.state = UserDefaultsManagement.hidePreview ? NSControl.StateValue.on : NSControl.StateValue.off

        cellSpacing.doubleValue = Double(UserDefaultsManagement.cellSpacing)

        showDockIcon.state = UserDefaultsManagement.showDockIcon ? .on : .off
        
        showInMenuBar.state = UserDefaultsManagement.showInMenuBar ? .on : .off
        
        previewFontSize.selectItem(withTag: UserDefaultsManagement.previewFontSize)

        hideImagesPreview.state = UserDefaultsManagement.hidePreviewImages ? .on : .off

        hideDate.state = UserDefaultsManagement.hideDate ? .on : .off

        firstLineAsTitle.state = UserDefaultsManagement.firstLineAsTitle ? .on : .off
    }

    @IBAction func verticalOrientation(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }

        UserDefaultsManagement.horizontalOrientation = false

        horizontalRadio.cell?.state = NSControl.StateValue(rawValue: 0)
        vc.splitView.isVertical = true
        vc.splitView.setPosition(215, ofDividerAt: 0)

        UserDefaultsManagement.cellSpacing = 38
        cellSpacing.doubleValue = Double(UserDefaultsManagement.cellSpacing)
        vc.setTableRowHeight()
    }

    @IBAction func horizontalOrientation(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }

        UserDefaultsManagement.horizontalOrientation = true

        verticalRadio.cell?.state = NSControl.StateValue(rawValue: 0)
        vc.splitView.isVertical = false
        vc.splitView.setPosition(145, ofDividerAt: 0)

        UserDefaultsManagement.cellSpacing = 12
        cellSpacing.doubleValue = Double(UserDefaultsManagement.cellSpacing)

        vc.setTableRowHeight()
        vc.notesTableView.reloadData()
    }

    @IBAction func changeCellSpacing(_ sender: NSSlider) {
        guard let vc = ViewController.shared() else { return }

        vc.setTableRowHeight()
    }

    @IBAction func changePreview(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }

        UserDefaultsManagement.hidePreview = ((sender as AnyObject).state == NSControl.StateValue.on)
        vc.notesTableView.reloadData()
    }

    @IBAction func hideImagesPreview(_ sender: NSButton) {
        UserDefaultsManagement.hidePreviewImages = sender.state == .on

        guard let vc = ViewController.shared() else { return }
        vc.notesTableView.reloadData()
    }

    @IBAction func changePreviewFontSize(_ sender: NSPopUpButton) {
        guard let tag = sender.selectedItem?.tag else { return }

        UserDefaultsManagement.previewFontSize = tag

        guard let vc = ViewController.shared() else { return }
        vc.notesTableView.reloadData()
    }

    @IBAction func hideDate(_ sender: NSButton) {
        UserDefaultsManagement.hideDate = (sender.state == .on)

        guard let vc = ViewController.shared() else { return }
        vc.notesTableView.reloadData()
    }

    @IBAction func firstLineAsTitle(_ sender: NSButton) {
        UserDefaultsManagement.firstLineAsTitle = (sender.state == .on)

        let storage = Storage.shared()
        for note in storage.noteList {
            note.invalidateCache()
        }

        guard let vc = ViewController.shared() else { return }
        vc.notesTableView.reloadData()
    }
    
    @IBAction func showDockIcon(_ sender: NSButton) {
        let isEnabled = sender.state == .on
        UserDefaultsManagement.showDockIcon = isEnabled

        NSApp.setActivationPolicy(isEnabled ? .regular : .accessory)

        DispatchQueue.main.async {
            NSMenu.setMenuBarVisible(true)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @IBAction func showInMenuBar(_ sender: NSButton) {
        UserDefaultsManagement.showInMenuBar = sender.state == .on

        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }

        if sender.state == .off {
            appDelegate.removeMenuBar(nil)
            return
        }

        appDelegate.addMenuBar(nil)
    }
}
