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
import FSNotesCore_macOS

class PrefsViewController: NSTabViewController  {

    @IBOutlet weak var generalTabViewItem: NSTabViewItem!
    @IBOutlet weak var libraryTabViewItem: NSTabViewItem!
    @IBOutlet weak var editorTabViewItem: NSTabViewItem!
    @IBOutlet weak var securityTabViewItem: NSTabViewItem!
    @IBOutlet weak var gitTabViewItem: NSTabViewItem!
    @IBOutlet weak var webTabViewItem: NSTabViewItem!
    @IBOutlet weak var advancedTabViewItem: NSTabViewItem!

    override func viewDidLoad() {
        self.title = NSLocalizedString("Settings", comment: "") 
        super.viewDidLoad()

        if #available(macOS 11.0, *) {
            let general = NSImage.init(systemSymbolName: "gearshape", accessibilityDescription: nil)
            let library = NSImage.init(systemSymbolName: "sidebar.left", accessibilityDescription: nil)
            let editor = NSImage.init(systemSymbolName: "doc.richtext", accessibilityDescription: nil)
            let security = NSImage.init(systemSymbolName: "lock", accessibilityDescription: nil)
            let git = NSImage.init(systemSymbolName: "arrow.triangle.pull", accessibilityDescription: nil)
            let web = NSImage.init(systemSymbolName: "globe", accessibilityDescription: nil)
            let advanced = NSImage.init(systemSymbolName: "slider.vertical.3", accessibilityDescription: nil)

            if let general = general, let library = library, let editor = editor, let security = security, let git = git, let web = web, let advanced = advanced {
                generalTabViewItem.image = general
                libraryTabViewItem.image = library
                editorTabViewItem.image = editor
                securityTabViewItem.image = security
                gitTabViewItem.image = git
                webTabViewItem.image = web
                advancedTabViewItem.image = advanced
            }
        }
    }

    override func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let toolbarItem = super.toolbar(toolbar, itemForItemIdentifier: itemIdentifier, willBeInsertedIntoToolbar: flag)

        if
            let toolbarItem = toolbarItem,
            let tabViewItem = tabViewItems.first(where: { ($0.identifier as? String) == itemIdentifier.rawValue })
        {
            if let name = tabViewItem.identifier as? String, name == "git" {
                toolbarItem.label = "\(tabViewItem.label)          "
                return toolbarItem
            }

            if let name = tabViewItem.identifier as? String, !["advanced", "security"].contains(name)  {
                toolbarItem.label = "\(tabViewItem.label)    "
            }
        }
        
        return toolbarItem
    }
}
