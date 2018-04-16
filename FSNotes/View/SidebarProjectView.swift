//
//  SidebarProjectView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/9/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Foundation
import Carbon.HIToolbox

class SidebarProjectView: NSOutlineView, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    var sidebarItems: [SidebarItem]? = nil
    var viewDelegate: ViewController? = nil
    
    private var storage = Storage.sharedInstance()
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.title == "Add root folder" {
            return true
        }
        
        let vc = getViewController()
        guard let sidebarItem = getSidebarItem(), sidebarItem.project != nil, vc.notesTableView.selectedRow == -1 else { return false }
        
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        delegate = self
        dataSource = self
        registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: "public.data")])
        
    }
    
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) && event.modifierFlags.contains(.shift) && event.keyCode == kVK_ANSI_N {
            addProject("")
            return
        }
        
        if event.modifierFlags.contains(.option) && event.modifierFlags.contains(.shift) && event.modifierFlags.contains(.command) && event.keyCode == kVK_ANSI_R {
            revealInFinder("")
            return
        }
        
        if event.modifierFlags.contains(.option) && event.modifierFlags.contains(.shift) && event.keyCode == kVK_ANSI_R {
            renameMenu("")
            return
        }
        
        if event.modifierFlags.contains(.option) && event.modifierFlags.contains(.shift) && event.keyCode == kVK_Delete {
            deleteMenu("")
            return
        }
        
        // Tab or right arrow to search
        if event.keyCode == 48 || event.keyCode == 124 {
            self.viewDelegate?.search.becomeFirstResponder()
            return
        }
        
        super.keyDown(with: event)
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        
        let board = info.draggingPasteboard()
        guard let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        
        guard let sidebarItem = item as? SidebarItem, let vd = viewDelegate, let project = sidebarItem.project else { return false }
        
        for url in urls {
            let name = url.lastPathComponent
            let note = Note(url: url)
            note.parseURL()
            note.reloadContent()
            note.project = project
            note.url = project.url.appendingPathComponent(name)
            note.save()
            note.markdownCache()
            vd.reloadView()
        }
        
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        
        return .copy
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let sidebar = sidebarItems else { return 0 }
        
        if item == nil {
            return sidebar.count
        }
        
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if let si = item as? SidebarItem, si.type == .Label {
            return 30
        }
        return 25
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let sidebar = sidebarItems else { return "" }
        
        if item == nil {
            return sidebar[index]
        }
        
        return ""
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        return item
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DataCell"), owner: self) as! SidebarCellView
        if let si = item as? SidebarItem {
            cell.textField?.stringValue = si.name
            
            switch si.type {
            case .All:
                cell.icon.image = NSImage(imageLiteralResourceName: "home.png")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25
                
            case .Trash:
                cell.icon.image = NSImage(imageLiteralResourceName: "trash.png")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25
                
            case .Label:
                cell.icon.isHidden = true
                cell.label.frame.origin.x = 5
                
            case .Category:
                cell.icon.image = NSImage(imageLiteralResourceName: "repository.png")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25
                
            default:
                break
            }
        }
        return cell
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        if let x = item as? SidebarItem, x.type == .Label {
            return true
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let x = item as? SidebarItem else {
            return false
        }
        
        if x.type == .Label && x.name == "Library" {
            return false
        }
        
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return SidebarTableRowView(frame: NSZeroRect)
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        if let view = notification.object as? NSOutlineView {
            guard let sidebar = sidebarItems, let vd = viewDelegate else { return }
            vd.editArea.clear()
                        
            let i = view.selectedRow
            if sidebar.indices.contains(i) {
                vd.updateTable() {}
            }
        }
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if (clickedRow > -1) {
            selectRowIndexes([clickedRow], byExtendingSelection: false)
            
            guard let si = sidebarItems, si.indices.contains(selectedRow) else { return }
            let sidebarItem = si[selectedRow]
            
            if ["Library", "Notes", "Trash"].contains(sidebarItem.name) && sidebarItem.project == nil {
                for item in menu.items {
                    if item.title != "Add" {
                        item.isHidden = true
                    }
                }
                
                return
            }
            
            for item in menu.items {
                item.isHidden = false
            }
            
            if let project = si[selectedRow].project, let i = menu.items.index(where: {$0.title == "Rename"}) {
                if project.isRoot {
                    menu.item(at: i)?.isHidden = true
                } else {
                    menu.item(at: i)?.isHidden = false
                }
            }
        }
    }
    
    @IBAction func revealInFinder(_ sender: Any) {
        guard let si = getSidebarItem(), let p = si.project else { return }
        
        NSWorkspace.shared.activateFileViewerSelecting([p.url])
    }
    
    @IBAction func renameMenu(_ sender: Any) {
        let vc = getViewController()
        guard let v = vc.storageOutlineView else { return }
        
        let selected = v.selectedRow
        guard let si = v.sidebarItems,
            si.indices.contains(selected) else { return }
        
        let sidebarItem = si[selected]
        guard
            sidebarItem.type == .Category,
            let projectRow = v.rowView(atRow: selected, makeIfNecessary: false),
            let cell = projectRow.view(atColumn: 0) as? SidebarCellView else { return }
        
        cell.label.isEditable = true
        cell.label.becomeFirstResponder()
    }
    
    @IBAction func deleteMenu(_ sender: Any) {
        let vc = getViewController()
        guard let v = vc.storageOutlineView else { return }
        
        let selected = v.selectedRow
        guard let si = v.sidebarItems, si.indices.contains(selected) else { return }
        
        let sidebarItem = si[selected]
        guard let project = sidebarItem.project, sidebarItem.type != .All || sidebarItem.type != .Trash || sidebarItem.name != "Library" else { return }
        
        if !project.isRoot && sidebarItem.type == .Category {
            guard let w = v.superview?.window else {
                return
            }
            
            let alert = NSAlert.init()
            alert.messageText = "Are you sure you want to remove project \"\(project.label)\" and all files inside?"
            alert.informativeText = "This action cannot be undone."
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: w) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    try? FileManager.default.trashItem(at: project.url, resultingItemURL: nil)
                    v.removeProject(project: project)
                }
            }
            return
        }
        
        SandboxBookmark().removeBy(project.url)
        v.removeProject(project: project)
    }
    
    @IBAction func addProject(_ sender: Any) {
        let vc = getViewController()
        guard let v = vc.storageOutlineView else { return }
        
        var unwrappedProject: Project?
        if let si = v.getSidebarItem(),
            let p = si.project {
            unwrappedProject = p
        }
        
        if sender is NSMenuItem, let mi = sender as? NSMenuItem, mi.title == "Add root folder" {
            unwrappedProject = nil
        }
        
        if sender is SidebarCellView, let cell = sender as? SidebarCellView, let si = cell.objectValue as? SidebarItem {
            if let p = si.project {
                unwrappedProject = p
            } else {
                addRoot()
                return
            }
        }
        
        guard let project = unwrappedProject else {
            addRoot()
            return
        }
        
        let window = NSApp.windows[0]
        let alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
        alert.messageText = "New project"
        alert.informativeText = "Please enter project name:"
        alert.accessoryView = field
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                self.addChild(field: field, project: project)
            }
        }
        
        field.becomeFirstResponder()
    }
    
    private func removeProject(project: Project) {
        self.storage.removeBy(project: project)
        
        self.viewDelegate?.restartFileWatcher()
        self.viewDelegate?.cleanSearchAndEditArea()
        
        self.sidebarItems = Sidebar().getList()
        self.reloadData()
    }
    
    private func addChild(field: NSTextField, project: Project) {
        let value = field.stringValue
        guard value.count > 0 else { return }
        
        do {
            let projectURL = project.url.appendingPathComponent(value, isDirectory: true)
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: false, attributes: nil)
            
            let newProject = Project(url: projectURL, parent: project.getParent())
            storage.add(project: newProject)
            reloadSidebar()
        } catch {
            let alert = NSAlert()
            alert.messageText = error.localizedDescription
            alert.runModal()
        }
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
                
                let newProject = Project(url: url, isRoot: true)
                self.storage.add(project: newProject)
                self.storage.loadLabel(newProject)
                self.reloadSidebar()
            }
        }
    }
    

    
    private func getViewController() -> ViewController {
        let vc = NSApp.windows.first?.contentViewController as? ViewController
        
        return vc!
    }
    
    private func getSidebarItem() -> SidebarItem? {
        let vc = getViewController()
        guard let v = vc.storageOutlineView else { return nil }
        
        let selected = v.selectedRow
        guard let si = v.sidebarItems,
            si.indices.contains(selected) else { return nil }
        
        let sidebarItem = si[selected]
        return sidebarItem
    }
    
    private func reloadSidebar() {
        let vc = getViewController()
        vc.restartFileWatcher()
        vc.loadMoveMenu()
        vc.storageOutlineView.sidebarItems = Sidebar().getList()
        vc.storageOutlineView.reloadData()
    }
    
}
