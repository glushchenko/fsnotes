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

import FSNotesCore_macOS

class SidebarProjectView: NSOutlineView,
    NSOutlineViewDelegate,
    NSOutlineViewDataSource,
    NSMenuItemValidation {
    
    var sidebarItems: [Any]? = nil
    var viewDelegate: ViewController? = nil
    
    private var storage = Storage.sharedInstance()
    public var isFirstLaunch = true

    private var selectedProjects = [Project]()
    private var selectedTags: [String]?

    override class func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.title == NSLocalizedString("Attach storage...", comment: "") {
            return true
        }

        guard let sidebarItem = getSidebarItem() else { return false }

        if menuItem.title == NSLocalizedString("Back up storage", comment: "") {

            if sidebarItem.isTrash() || sidebarItem.tag != nil {
                return false
            }

            return true
        }

        if menuItem.title == NSLocalizedString("Show in Finder", comment: "") {
            if let sidebarItem = getSidebarItem() {
                return sidebarItem.project != nil || sidebarItem.isTrash()
            }
        }

        if menuItem.title == NSLocalizedString("Rename folder", comment: "") {
            if sidebarItem.isTrash() {
                return false
            }

            if let project = sidebarItem.project {
                menuItem.isHidden = project.isRoot
            }

            if let project = sidebarItem.project, !project.isDefault, !project.isArchive {
                return true
            }
        }

        if menuItem.title == NSLocalizedString("Delete folder", comment: "")
            || menuItem.title == NSLocalizedString("Detach storage", comment: "") {

            if sidebarItem.isTrash() {
                return false
            }

            if let project = sidebarItem.project {
                menuItem.title = project.isRoot
                    ? NSLocalizedString("Detach storage", comment: "")
                    : NSLocalizedString("Delete folder", comment: "")
            }

            if let project = sidebarItem.project, !project.isDefault, !project.isArchive {
                return true
            }
        }

        if menuItem.title == NSLocalizedString("Show view options", comment: "") {
            if sidebarItem.isTrash() {
                return false
            }

            return nil != sidebarItem.project
        }

        if menuItem.title == NSLocalizedString("New folder", comment: "") {
            if sidebarItem.isTrash() {
                return false
            }
            
            if let project = sidebarItem.project, !project.isArchive {
                return true
            }
        }

        return false
    }

    override func draw(_ dirtyRect: NSRect) {
        delegate = self
        dataSource = self
        registerForDraggedTypes([
            NSPasteboard.PasteboardType(rawValue: "public.data"),
            NSPasteboard.PasteboardType.init(rawValue: "notesTable")
        ])
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
        guard let sidebarItem = item as? SidebarItem else { return false }
        guard let vc = ViewController.shared() else { return false }

        let board = info.draggingPasteboard

        switch sidebarItem.type {
        case .Tag:
            if let data = board.data(forType: NSPasteboard.PasteboardType.init(rawValue: "notesTable")), let rows = NSKeyedUnarchiver.unarchiveObject(with: data) as? IndexSet {

                for row in rows {
                    let note = vc.notesTableView.noteList[row]
                    note.addTag(sidebarItem.name)
                    selectTag(item: sidebarItem)
                }
                
                return true
            }
            break
        case .Label, .Category, .Trash, .Archive, .Inbox:
            if let data = board.data(forType: NSPasteboard.PasteboardType.init(rawValue: "notesTable")), let rows = NSKeyedUnarchiver.unarchiveObject(with: data) as? IndexSet {

                var notes = [Note]()
                for row in rows {
                    let note = vc.notesTableView.noteList[row]
                    notes.append(note)
                }

                if let project = sidebarItem.project {
                    vc.move(notes: notes, project: project)
                } else if sidebarItem.isTrash() {
                    vc.editArea.clear()
                    vc.storage.removeNotes(notes: notes) { _ in
                        DispatchQueue.main.async {
                            vc.storageOutlineView.reloadSidebar()
                            vc.notesTableView.removeByNotes(notes: notes)
                        }
                    }
                }
                
                return true
            }
            
            guard let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                let project = sidebarItem.project else { return false }
            
            for url in urls {
                var isDirectory = ObjCBool(true)
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue && !url.path.contains(".textbundle") {

                    let newSub = project.url.appendingPathComponent(url.lastPathComponent, isDirectory: true)
                    let newProject = Project(url: newSub, parent: project)
                    newProject.create()

                    _ = self.storage.add(project: newProject)
                    self.reloadSidebar()

                    let validFiles = self.storage.readDirectory(url)
                    for file in validFiles {
                        _ = vc.copy(project: newProject, url: file.0)
                    }
                } else {
                    _ = vc.copy(project: project, url: url)
                }
            }
            
            return true
        default:
            break
        }

        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard let sidebarItem = item as? SidebarItem else { return NSDragOperation() }
        let board = info.draggingPasteboard

        switch sidebarItem.type {
        case .Tag, .Trash:
            if let data = board.data(forType: NSPasteboard.PasteboardType.init(rawValue: "notesTable")), !data.isEmpty {
                return .copy
            }
            break
        case .Category, .Label, .Archive, .Inbox:
            guard sidebarItem.isSelectable() else { break }
            
            if let data = board.data(forType: NSPasteboard.PasteboardType.init(rawValue: "notesTable")), !data.isEmpty {
                return .move
            }
            
            if let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], urls.count > 0 {
                return .copy
            }
            break
        default:
            break
        }
        
        return NSDragOperation()
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let tag = item as? Tag {
            return tag.getChild().count
        }

        if let item = item as? SidebarItem, let tag = item.tag {
            return tag.getChild().count
        }

        if let sidebar = sidebarItems, item == nil {
            return sidebar.count
        }
        
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if let si = item as? SidebarItem, si.type == .Label {
            return 45
        }
        return 25
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let tag = item as? Tag {
            return tag.isExpandable()
        }

        if let item = item as? SidebarItem, item.type == .Tag, let tag = item.tag {
            return tag.isExpandable()
        }

        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let tag = item as? Tag {
            return tag.getChild()[index]
        }

        if let si = item as? SidebarItem, si.type == .Tag, let tag = si.tag {
            return tag.getChild()[index]
        }

        if let sidebar = sidebarItems, item == nil {
            return sidebar[index]
        }
        
        return ""
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        return item
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DataCell"), owner: self) as! SidebarCellView

        if let tag = item as? Tag {
            
            cell.icon.image = NSImage(imageLiteralResourceName: "tag.png")
            cell.icon.isHidden = false
            cell.label.frame.origin.x = 25
            cell.textField?.stringValue = tag.getName()

        } else if let si = item as? SidebarItem {
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
                if let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderCell"), owner: self) as? SidebarHeaderCellView {
                    cell.title.stringValue = si.name
                    return cell
                }
            case .Category:
                cell.icon.image = NSImage(imageLiteralResourceName: "repository.png")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25
                
            case .Tag:
                cell.icon.image = NSImage(imageLiteralResourceName: "tag.png")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25

            case .Archive:
                cell.icon.image = NSImage(imageLiteralResourceName: "archive.png")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25
            
            case .Todo:
                cell.icon.image = NSImage(imageLiteralResourceName: "todo_sidebar.png")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25

            case .Inbox:
                cell.icon.image = NSImage(imageLiteralResourceName: "sidebarInbox")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25
            }
        }
        return cell
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if nil != item as? Tag {
            return true
        }

        guard let sidebarItem = item as? SidebarItem else {
            return false
        }
        
        return sidebarItem.isSelectable()
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return SidebarTableRowView(frame: NSZeroRect)
    }

    override func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        guard let index = indexes.first else { return }

        var extend = extend

        if (item(atRow: index) as? Tag) != nil {
            for i in selectedRowIndexes {
                if nil != item(atRow: i) as? Tag {
                    deselectRow(i)
                }
            }

            extend = true
        }

        super.selectRowIndexes(indexes, byExtendingSelection: extend)
    }

    private func isChangedSelectedProjectsState() -> Bool {
        var qtyChanged = false
        if selectedProjects.count == 0 {
            for i in selectedRowIndexes {
                if let si = item(atRow: i) as? SidebarItem, let project = si.project, si.tag == nil {
                    selectedProjects.append(project)
                    qtyChanged = true
                }
            }
        } else {
            var new = [Project]()
            for i in selectedRowIndexes {
                if let si = item(atRow: i) as? SidebarItem, let project = si.project, si.tag == nil {
                    new.append(project)
                    if !selectedProjects.contains(project) {
                        qtyChanged = true
                    }
                }
            }
            selectedProjects = new

            if new.count == 0 {
                qtyChanged = true
            }
        }

        return qtyChanged
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        if UserDataService.instance.isNotesTableEscape {
            UserDataService.instance.isNotesTableEscape = false
        }

        guard let sidebarItems = sidebarItems else { return }

        selectedTags = getSidebarTags()

        if UserDefaultsManagement.inlineTags, isChangedSelectedProjectsState() {
            reloadTags()
        }
        
        if let view = notification.object as? NSOutlineView {
            let sidebar = sidebarItems
            guard let vd = viewDelegate else { return }

            let i = view.selectedRow

            if sidebar.indices.contains(i), let item = sidebar[i] as? SidebarItem {
                if UserDataService.instance.lastType == item.type.rawValue && UserDataService.instance.lastProject == item.project?.url &&
                    UserDataService.instance.lastName == item.name {
                    return
                }

                UserDefaultsManagement.lastProject = i

                UserDataService.instance.lastType = item.type.rawValue
                UserDataService.instance.lastProject = item.project?.url
                UserDataService.instance.lastName = item.name
            }

            vd.editArea.clear()

            if !isFirstLaunch {
                vd.search.stringValue = ""
            }

            guard !UserDataService.instance.skipSidebarSelection else {
                UserDataService.instance.skipSidebarSelection = false
                return
            }

            vd.updateTable() {
                if self.isFirstLaunch {
                    if let url = UserDefaultsManagement.lastSelectedURL,
                        let lastNote = vd.storage.getBy(url: url),
                        let i = vd.notesTableView.getIndex(lastNote)
                    {
                        vd.notesTableView.selectRow(i)

                        DispatchQueue.main.async {
                            vd.notesTableView.scrollRowToVisible(i)
                        }
                    } else if vd.notesTableView.noteList.count > 0 {
                        vd.focusTable()
                    }
                    self.isFirstLaunch = false
                }
            }
        }
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if (clickedRow > -1) {
            selectRowIndexes([clickedRow], byExtendingSelection: false)

            for item in menu.items {
                item.isHidden = !validateMenuItem(item)
            }
        }
    }
    
    @IBAction func revealInFinder(_ sender: Any) {
        guard let si = getSidebarItem(), let p = si.project else { return }
        
        NSWorkspace.shared.activateFileViewerSelecting([p.url])
    }
    
    @IBAction func renameMenu(_ sender: Any) {
        guard let vc = ViewController.shared(), let v = vc.storageOutlineView else { return }
        
        let selected = v.selectedRow
        guard let si = v.sidebarItems,
            si.indices.contains(selected) else { return }
        
        guard
            let sidebarItem = si[selected] as? SidebarItem,
            sidebarItem.type == .Category,
            let projectRow = v.rowView(atRow: selected, makeIfNecessary: false),
            let cell = projectRow.view(atColumn: 0) as? SidebarCellView else { return }
        
        cell.label.isEditable = true
        cell.label.becomeFirstResponder()
    }
    
    @IBAction func deleteMenu(_ sender: Any) {
        guard let vc = ViewController.shared(), let v = vc.storageOutlineView else { return }
        
        let selected = v.selectedRow
        guard let si = v.sidebarItems, si.indices.contains(selected) else { return }
        

        guard let sidebarItem = si[selected] as? SidebarItem, let project = sidebarItem.project, !project.isDefault && sidebarItem.type != .All && sidebarItem.type != .Trash  else { return }
        
        if !project.isRoot && sidebarItem.type == .Category {
            guard let w = v.superview?.window else {
                return
            }
            
            let alert = NSAlert.init()
            let messageText = NSLocalizedString("Are you sure you want to remove project \"%@\" and all files inside?", comment: "")
            
            alert.messageText = String(format: messageText, project.label)
            alert.informativeText = NSLocalizedString("This action cannot be undone.", comment: "Delete menu")
            alert.addButton(withTitle: NSLocalizedString("Remove", comment: "Delete menu"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Delete menu"))
            alert.beginSheetModal(for: w) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {

                    guard let resultingItemUrl = Storage.sharedInstance().trashItem(url: project.url) else { return }

                    do {
                        try FileManager.default.moveItem(at: project.url, to: resultingItemUrl)

                        v.removeProject(project: project)
                    } catch {
                        print(error)
                    }
                }
            }
            return
        }
        
        SandboxBookmark().removeBy(project.url)
        v.removeProject(project: project)
    }
    
    @IBAction func addProject(_ sender: Any) {
        guard let vc = ViewController.shared(), let v = vc.storageOutlineView else { return }
        
        var unwrappedProject: Project?
        if let si = v.getSidebarItem(),
            let p = si.project {
            unwrappedProject = p
        }
        
        if sender is NSMenuItem,
            let mi = sender as? NSMenuItem,
            mi.title == NSLocalizedString("Attach storage...", comment: "") {
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
        
        guard let window = MainWindowController.shared() else { return }
        
        let alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
        alert.messageText = NSLocalizedString("New project", comment: "")
        alert.informativeText = NSLocalizedString("Please enter project name:", comment: "")
        alert.accessoryView = field
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("Add", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                self.addChild(field: field, project: project)
            }
        }
        
        field.becomeFirstResponder()
    }

    @IBAction func openSettings(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }

        vc.openProjectViewSettings(sender)
    }

    private func removeProject(project: Project) {
        self.storage.removeBy(project: project)
        
        self.viewDelegate?.fsManager?.restart()
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
            _ = storage.add(project: newProject)
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
                let projects = self.storage.add(project: newProject)
                for project in projects {
                    self.storage.loadLabel(project)
                }
                
                self.reloadSidebar()
            }
        }
    }

    public func getSidebarProjects() -> [Project]? {
        guard let vc = ViewController.shared(), let v = vc.storageOutlineView else { return nil }

        var projects = [Project]()
        for i in v.selectedRowIndexes {
            if let si = item(atRow: i) as? SidebarItem, let project = si.project, si.tag == nil {
                projects.append(project)
            }
        }

        if projects.count > 0 {
            return projects
        }

        if let root = Storage.sharedInstance().getRootProject() {
            return [root]
        }

        return nil
    }

    public func getSidebarTags() -> [String]? {
        guard let vc = ViewController.shared(), let v = vc.storageOutlineView else { return nil }

        var tags = [String]()
        for i in v.selectedRowIndexes {
            if let tag = (item(atRow: i) as? Tag)?.getFullName() {
                tags.append(tag)
            }
        }

        if tags.count > 0 {
            return tags
        }

        return nil
    }

    public func getSelectedInlineTags() -> String {
        var inlineTags = String()
        if let tags = getSidebarTags() {
            for tag in tags {
                inlineTags += "#\(tag) "
            }
        }
        return inlineTags
    }

    private func getSidebarItem() -> SidebarItem? {
        guard let vc = ViewController.shared(), let v = vc.storageOutlineView else { return nil }
        
        let selected = v.selectedRow
        guard let si = v.sidebarItems,
            si.indices.contains(selected) else { return nil }
        
        let sidebarItem = si[selected] as? SidebarItem
        return sidebarItem
    }
    
    @objc public func reloadSidebar() {
        guard let vc = ViewController.shared() else { return }
        vc.fsManager?.restart()
        vc.loadMoveMenu()

        let selected = vc.storageOutlineView.selectedRow
        vc.storageOutlineView.sidebarItems = Sidebar().getList()
        vc.storageOutlineView.reloadData()
        vc.storageOutlineView.selectRowIndexes([selected], byExtendingSelection: false)

        vc.storageOutlineView.loadAllTags()
    }
    
    public func deselectTags(_ list: [String]) {
        for tag in list {
            if
                let i = sidebarItems?.firstIndex(where: { ($0 as? SidebarItem)?.type == .Tag && ($0 as? SidebarItem)?.name == tag }),
                let row = self.rowView(atRow: i, makeIfNecessary: false),
                let cell = row.view(atColumn: 0) as? SidebarCellView {
                
                cell.icon.image = NSImage(named: "tag.png")
            }
        }
    }
    
    public func selectTag(item: SidebarItem) {
        let i = self.row(forItem: item)
        if let row = self.rowView(atRow: i, makeIfNecessary: true), let cell = row.view(atColumn: 0) as? SidebarCellView {
            cell.icon.image = NSImage(named: "tag_red.png")
        }
    }
    
    public func deselectTag(item: SidebarItem) {
        let i = self.row(forItem: item)
        if let row = self.rowView(atRow: i, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarCellView {
            cell.icon.image = NSImage(named: "tag.png")
        }
    }
    
    public func deselectAllTags() {
        guard let items = self.sidebarItems?.filter({($0 as? SidebarItem)?.type == .Tag}) else { return }
        for item in items {
            let i = self.row(forItem: item)
            if let row = self.rowView(atRow: i, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarCellView {
                cell.icon.image = NSImage(named: "tag.png")
            }
        }
    }

    public func selectArchive() {
        if let i = sidebarItems?.firstIndex(where: {($0 as? SidebarItem)?.type == .Archive }) {
            selectRowIndexes([i], byExtendingSelection: false)
        }
    }
    
    public func remove(sidebarItem: SidebarItem) {
        if let i = sidebarItems?.firstIndex(where: {($0 as? SidebarItem)?.type == .Tag && ($0 as? SidebarItem)?.name == sidebarItem.name }) {
            sidebarItems?.remove(at: i)
            self.removeItems(at: [i], inParent: nil, withAnimation: .effectFade)
        }
    }

    public func remove(tagName: String) {
        let tags = tagName.components(separatedBy: "/")
        guard let parent = tags.first else { return }

        if let tag = sidebarItems?.first(where: {($0 as? Tag)?.getName() == parent }) as? Tag {
            if tags.count == 1 {
                let allTags = getSidebarTags()
                let count = allTags?.filter({ $0.starts(with: parent) }).count ?? 0

                if count == 0 {
                    let i = row(forItem: tag)
                    if let ind = sidebarItems?.indices, ind.contains(i) {
                        sidebarItems?.remove(at: i)
                        removeItems(at: [i], inParent: nil, withAnimation: .effectFade)
                    }
                }
            } else if var foundTag = tag.find(name: tagName) {
                while let parent = foundTag.getParent() {
                    if let i = parent.indexOf(child: foundTag) {
                        parent.remove(by: i)
                        removeItems(at: [i], inParent: parent, withAnimation: .effectFade)
                    }

                    if
                        parent.getParent() == nil
                        && parent.getChild().count == 0,
                        let i = sidebarItems?.firstIndex(where: { ($0 as? Tag)?.getName() == parent.getName() })
                    {
                        removeItems(at: [i], inParent: nil, withAnimation: .effectFade)
                        sidebarItems?.remove(at: i)
                        break
                    }

                    foundTag = parent
                }
            }
        }
    }

    public func addTags(_ tags: [String]) {
        self.beginUpdates()
        for tag in tags {
            let subtags = tag.components(separatedBy: "/")

            if
                let first = subtags.first,
                let tag = sidebarItems?.first(where: { ($0 as? Tag)?.getName() == first }) as? Tag {

                if subtags.count == 1 {
                    continue
                }

                let sub = subtags.dropFirst().joined(separator: "/")
                tag.addChild(name: sub, completion: { (tag) in
                    if let parent = tag.getParent() {
                        let count = parent.getChild().count
                        self.insertItems(at: [count], inParent: tag.getParent(), withAnimation: .slideDown)
                    }
                })
            } else {
                let position = sidebarItems?.count ?? 0
                let rootTag = Tag(name: tag)
                sidebarItems?.append(rootTag)
                self.insertItems(at: [position], inParent: nil, withAnimation: .effectFade)
            }
        }
        self.endUpdates()
    }
    
    public func removeTags(_ tags: [String]) {
        var removeTags = [String]()
        for tag in tags {
            if isAllowRemoveTag(tag) {
                removeTags.append(tag)
            }
        }

        for tag in removeTags {
            remove(tagName: tag)
        }
    }

    public func isAllowRemoveTag(_ name: String) -> Bool {
        guard let vc = ViewController.shared() else { return false }

        var allow = true
        for note in vc.notesTableView.noteList {
            for tag in note.tags {
                if tag.starts(with: name) {
                    allow = false
                }
            }
        }

        return allow
    }

    private func reloadTags() {
        unloadAllTags()
        loadAllTags()
    }

    public func unloadAllTags() {
        if let firstIndex = sidebarItems?.firstIndex(where: {($0 as? SidebarItem)?.name == "# Tags"}) {
            beginUpdates()

            let count = (sidebarItems?.count ?? 0) - 1
            for i in (firstIndex...count).reversed() {
                if let item = sidebarItems?[i] as? Tag {
                    let index = row(forItem: item)
                    sidebarItems?.remove(at: i)
                    removeItems(at: [index], inParent: nil, withAnimation: .slideDown)
                }
            }

            endUpdates()
        }
    }

    public func getAllTags() -> [String] {
        var tags = [String]()

        if let projects = getSidebarProjects() {
            for project in projects {
                let projectTags = project.getAllTags()
                for tag in projectTags {
                    if !tags.contains(tag) {
                        tags.append(tag)
                    }
                }
            }
        }

        return tags
    }

    private func loadAllTags() {
        let tags = getAllTags()

        addTags(tags.sorted())
    }
}
