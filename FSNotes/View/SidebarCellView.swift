//
//  SidebarCellView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class SidebarCellView: NSTableCellView {
    @IBOutlet weak var icon: NSImageView!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var plus: NSButton!
    
    var storage = Storage.sharedInstance()
    
    override func draw(_ dirtyRect: NSRect) {
        plus.isHidden = true

        super.draw(dirtyRect)
    }
    
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard let sidebarItem = objectValue as? SidebarItem else { return }
        
        let tagsLabel = NSLocalizedString("Tags", comment: "Sidebar label")
        
        if sidebarItem.type == .Label && sidebarItem.name != "# \(tagsLabel)" {
            plus.isHidden = false
            
            return
        }
        
        let vc = getViewController()
        if sidebarItem.type == .Tag, let note = vc.notesTableView.getSelectedNote() {
            if note.tagNames.contains(sidebarItem.name) {
                plus.alternateTitle = sidebarItem.name
                plus.image = NSImage.init(named: NSImage.Name.stopProgressTemplate)
                plus.image?.size = NSSize(width: 10, height: 10)
                plus.isHidden = false
                plus.target = self
                plus.action = #selector(removeTag(sender:))
            } else {
                plus.alternateTitle = sidebarItem.name
                plus.image = NSImage.init(named: NSImage.Name.addTemplate)
                plus.image?.size = NSSize(width: 10, height: 10)
                plus.isHidden = false
                plus.target = self
                plus.action = #selector(addTag(sender:))
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let sidebarItem = objectValue as? SidebarItem else { return }
        
        if sidebarItem.type == .Label || sidebarItem.type == .Tag {
            plus.isHidden = true
        }
    }
    
    @IBAction func projectName(_ sender: NSTextField) {
        let cell = sender.superview as? SidebarCellView
        guard let si = cell?.objectValue as? SidebarItem, let project = si.project else { return }
        
        let newURL = project.url.deletingLastPathComponent().appendingPathComponent(sender.stringValue)
        
        do {
            try FileManager.default.moveItem(at: project.url, to: newURL)
            project.url = newURL
            project.label = newURL.lastPathComponent
            
        } catch {
            sender.stringValue = project.url.lastPathComponent
            let alert = NSAlert()
            alert.messageText = error.localizedDescription
            alert.runModal()
        }
        
        guard let vc = self.window?.contentViewController as? ViewController else { return }
        vc.storage.removeBy(project: project)
        vc.storage.loadLabel(project)
        vc.updateTable()
    }
    
    @IBAction func add(_ sender: Any) {
        let vc = getViewController()
        vc.storageOutlineView.addProject(self)
    }
    
    private func getViewController() -> ViewController {
        let vc = NSApp.windows[0].contentViewController as? ViewController
        
        return vc!
    }
    
    @objc public func removeTag(sender: Any?) {
        guard let button = sender as? NSButton else { return }
        
        let vc = getViewController()
        if let note = vc.notesTableView.getSelectedNote() {
            let tag = button.alternateTitle
            note.removeTag(tag)
            
            let vc = getViewController()
            
            if let sidebarItem = vc.storageOutlineView.sidebarItems?.first(where: {$0.type == .Tag && $0.name == tag}) {
                vc.storageOutlineView.deselectTag(item: sidebarItem)
                
                if !vc.storage.tagNames.contains(tag) {
                    vc.storageOutlineView.remove(sidebarItem: sidebarItem)
                }
            }
        }
    }
    
    @objc public func addTag(sender: Any?) {
        guard let button = sender as? NSButton else { return }
        
        let vc = getViewController()
        if let note = vc.notesTableView.getSelectedNote() {
            let tag = button.alternateTitle
            note.addTag(tag)
            
            let vc = getViewController()
            
            if let sidebarItem = vc.storageOutlineView.sidebarItems?.first(where: {$0.type == .Tag && $0.name == tag}) {
                vc.storageOutlineView.selectTag(item: sidebarItem)
            }
        }
    }

}
