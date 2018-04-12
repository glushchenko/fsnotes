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
        
        if sidebarItem.type == .Label {
            plus.isHidden = false
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let sidebarItem = objectValue as? SidebarItem else { return }
        
        if sidebarItem.type == .Label {
            plus.isHidden = true
        }
    }
    
    @IBAction func add(_ sender: NSButton) {
        let cell = sender.superview as? SidebarCellView
        guard let si = cell?.objectValue as? SidebarItem else {
            return
        }
        
        guard let project = si.project else {
            addRoot()
            return
        }
        
        let alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
        alert.messageText = "Please enter project name:"
        alert.accessoryView = field
        alert.alertStyle = .informational
        alert.runModal()
        
        let value = field.stringValue
        guard value.count > 0 else { return }
        
        do {
            let projectURL = project.url.appendingPathComponent(value, isDirectory: true)
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: false, attributes: nil)
            
            let newProject = Project(url: projectURL, parent: project)
            storage.add(project: newProject)
            
            let vc = getViewController()
            vc.restartFileWatcher()
            
            if let sidebar = superview?.superview as? SidebarProjectView {
                sidebar.sidebarItems = Sidebar().getList()
                sidebar.reloadData()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = error.localizedDescription
            alert.runModal()
        }
    }
    
    @IBAction func projectName(_ sender: NSTextField) {
        let cell = sender.superview as? SidebarCellView
        guard let si = cell?.objectValue as? SidebarItem, let project = si.project else { return }
        
        let newURL = project.url.deletingLastPathComponent().appendingPathComponent(sender.stringValue)
        print(newURL)
        
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
        
        // reload storage data
        guard let vc = self.window?.contentViewController as? ViewController else { return }
        
        vc.storage.removeBy(project: project)
        vc.storage.loadLabel(project)
        vc.updateTable {}
    }
    
    private func addRoot() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                guard let url = openPanel.url else {
                    return
                }
                
                guard !self.storage.projectExist(url: url) else {
                    return
                }

                let bookmark = SandboxBookmark.sharedInstance()
                _ = bookmark.load()
                bookmark.store(url: url)
                bookmark.save()
                
                let vc = self.getViewController()
                let newProject = Project(url: url, isRoot: true)
                self.storage.add(project: newProject)
                vc.restartFileWatcher()
                
                if let sidebar = self.superview?.superview as? SidebarProjectView {
                    sidebar.sidebarItems = Sidebar().getList()
                    sidebar.reloadData()
                }
            }
        }
    }
    
    private func getViewController() -> ViewController {
        let vc = self.window?.contentViewController as? ViewController
        
        return vc!
    }
    
    
    
}
