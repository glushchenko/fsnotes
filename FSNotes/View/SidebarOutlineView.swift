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

class SidebarOutlineView: NSOutlineView,
    NSOutlineViewDelegate,
    NSOutlineViewDataSource,
    NSMenuItemValidation {
    
    var sidebarItems: [Any]? = nil
    var viewDelegate: ViewController? = nil
    
    private var storage = Storage.sharedInstance()
    public var isFirstLaunch = true
    public var selectNote: Note? = nil

    private var selectedProjects = [Project]()
    private var selectedTags: [String]?
    private var lastSelectedRow: Int?

    private var cellView: SidebarCellView?

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let id = menuItem.identifier?.rawValue else { return false }

        if id == "folderMenu.attach" {
            return true
        }

        guard let project = getSelectedProject() else { return false }

        if id == "folderMenu.backup" {
            if project.isTrash {
                return false
            }

            return true
        }

        if id == "folderMenu.reveal" {
            return true
        }

        if id == "folderMenu.rename" {
            if project.isTrash {
                return false
            }

            menuItem.isHidden = project.isRoot

            if !project.isDefault, !project.isArchive {
                return true
            }
        }

        if id == "folderMenu.delete" {
            if project.isTrash {
                return false
            }

            menuItem.title = project.isRoot
                ? NSLocalizedString("Detach storage", comment: "")
                : NSLocalizedString("Delete folder", comment: "")


            if !project.isDefault, !project.isArchive {
                return true
            }
        }

        if id == "folderMenu.options" {
            return !project.isTrash
        }

        if id == "folderMenu.new" {
            if project.isTrash {
                return false
            }
            
            if !project.isArchive {
                return true
            }
        }

        return false
    }

    override func draw(_ dirtyRect: NSRect) {
        allowsTypeSelect = false
        delegate = self
        dataSource = self
        registerForDraggedTypes([
            NSPasteboard.PasteboardType(kUTTypeFileURL as String),
            NSPasteboard.noteType
        ])
        super.draw(dirtyRect)
    }
    
    override func keyDown(with event: NSEvent) {
        // Tab to search
        if event.keyCode == kVK_Tab {
            self.viewDelegate?.search.becomeFirstResponder()
            return
        }

        // Focus on note list
        if event.keyCode == kVK_RightArrow {
            if let fr = NSApp.mainWindow?.firstResponder, let vc = self.viewDelegate, fr.isKind(of: SidebarOutlineView.self) {

                if let tag = item(atRow: selectedRow) as? Tag, tag.isExpandable(), !isItemExpanded(tag) {
                    super.keyDown(with: event)
                    return
                }

                if let project = item(atRow: selectedRow) as? Project, project.isExpandable(), !isItemExpanded(project) {
                    super.keyDown(with: event)
                    return
                }

                vc.notesTableView.selectNext()
                NSApp.mainWindow?.makeFirstResponder(vc.notesTableView)
                return
            }
        }

        super.keyDown(with: event)
    }

    override func expandItem(_ item: Any?, expandChildren: Bool) {
        if let project = item as? Project {
            project.isExpanded = true
        }

        super.expandItem(item, expandChildren: expandChildren)

        storage.saveProjectsExpandState()
    }

    override func collapseItem(_ item: Any?, collapseChildren: Bool) {
        if let project = item as? Project {
            project.isExpanded = false
        }

        super.collapseItem(item, collapseChildren: collapseChildren)

        storage.saveProjectsExpandState()
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let vc = ViewController.shared() else { return false }
        let board = info.draggingPasteboard

        var urls = [URL]()
        if let data = info.draggingPasteboard.data(forType: NSPasteboard.noteType),
           let unarchivedData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [URL] {
            urls = unarchivedData
        }

        var project: Project?

        if let sidebarItem = item as? SidebarItem, let sidebarProject = sidebarItem.project {
            project = sidebarProject
        }

        if let sidebarProject = item as? Project {
            project = sidebarProject
        }

        guard let project = project else { return false }

        if urls.count > 0, Storage.sharedInstance().getBy(url: urls.first!) != nil {
            var notes = [Note]()
            for url in urls {
                if let note = Storage.sharedInstance().getBy(url: url) {
                    notes.append(note)
                }
            }

            if project.isTrash {
                vc.editArea.clear()
                vc.storage.removeNotes(notes: notes) { _ in
                    DispatchQueue.main.async {
                        vc.notesTableView.removeByNotes(notes: notes)
                    }
                }
            } else {
                vc.move(notes: notes, project: project)
            }

            return true
        }

        guard let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }

        for url in urls {
            var isDirectory = ObjCBool(true)
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue && !url.path.contains(".textbundle") {

                let newSub = project.url.appendingPathComponent(url.lastPathComponent, isDirectory: true)
                let newProject =
                    Project(
                        storage: self.storage,
                        url: newSub,
                        parent: project
                    )

                newProject.create()

                self.storage.assignTree(for: newProject)
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
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        let board = info.draggingPasteboard
        var isLocalNote = false
        var urls = [URL]()

        if let archivedData = info.draggingPasteboard.data(forType: NSPasteboard.noteType),
           let urlsUnarchived = NSKeyedUnarchiver.unarchiveObject(with: archivedData) as? [URL] {
            urls = urlsUnarchived

            if let url = urls.first, Storage.sharedInstance().getBy(url: url) != nil {
                isLocalNote = true
            }
        }

        if !UserDefaultsManagement.inlineTags, nil != item as? Tag {
            if isLocalNote {
                return .copy
            }
        }

        if item as? Project != nil {
            return .copy
        }

        guard let sidebarItem = item as? SidebarItem else { return NSDragOperation() }
        switch sidebarItem.type {
        case .Trash:
            if isLocalNote {
                return .copy
            }
            break
        case .Label, .Archive, .Inbox:
            guard sidebarItem.isSelectable() else { break }
            
            if isLocalNote {
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
            return tag.child.count
        }

        if let project = item as? Project {
            return project.child.count
        }

        if let sidebar = sidebarItems, item == nil {
            return sidebar.count
        }
        
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if let si = item as? SidebarItem, si.type == .Label {
            return 15
        }
        return 25
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let tag = item as? Tag {
            return tag.isExpandable()
        }

        if let project = item as? Project {
            return project.isExpandable()
        }

        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let tag = item as? Tag {
            return tag.child[index]
        }

        if let project = item as? Project {
            return project.child[index]
        }

        if let sidebar = sidebarItems, item == nil {
            return sidebar[index]
        }
        
        return String()
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        return item
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DataCell"), owner: self) as! SidebarCellView

        if let tag = item as? Tag {
            
            cell.icon.image = NSImage(named: "tag")
            cell.icon.isHidden = false
            cell.label.frame.origin.x = 25
            cell.textField?.stringValue = tag.getName()

        } else if let project = item as? Project {

            cell.icon.image = NSImage(named: "project")
            cell.icon.isHidden = false
            cell.label.frame.origin.x = 25
            cell.textField?.stringValue = project.label

        } else if let si = item as? SidebarItem {
            cell.textField?.stringValue = si.name

            switch si.type {
            case .Label:
                if let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderCell"), owner: self) as? SidebarHeaderCellView {
                    cell.title.stringValue = ""
                    return cell
                }

            case .All:
                cell.icon.image = NSImage(imageLiteralResourceName: "home.png")
                cell.icon.isHidden = false
                cell.label.frame.origin.x = 25
                
            case .Trash:
                cell.icon.image = NSImage(imageLiteralResourceName: "trashBin")
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

        if nil != item as? Project {
            return true
        }

        if let sidebarItem = item as? SidebarItem {
            return sidebarItem.isSelectable()
        }
        
        return false
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

    public func removeTags(notes: [Note]) {
        guard let vc = ViewController.shared() else { return }

        var allNoteTags: Set<String> = []
        for note in vc.notesTableView.noteList {
            for tag in note.tags {
                if !allNoteTags.contains(tag) {
                    allNoteTags.insert(tag)
                }
            }
        }

        var allRemoveTags = [String]()
        for note in notes {
            for tag in note.tags {
                allRemoveTags.append(tag)
            }
        }

        var remove = [String]()
        for tag in allRemoveTags {
            if !allNoteTags.contains(tag) {
                remove.append(tag)
            }
        }

        removeTags(remove)
    }

    public func insertTags(note: Note) {
        var tags = [String]()
        for tag in note.tags {
            if !tags.contains(tag) {
                tags.append(tag)
            }
        }

        var sTags: Set<String> = []
        if let allSidebarTags = sidebarItems?.filter({ ($0 as? Tag) != nil }).map({ ($0 as? Tag)!.getFullName() }) {
            sTags = Set(allSidebarTags)
        }

        var insert = [String]()
        for tag in tags {
            if !sTags.contains(tag) {
                insert.append(tag)
            }
        }

        addTags(insert)
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
        guard let vd = viewDelegate else { return }

        if UserDataService.instance.isNotesTableEscape {
            UserDataService.instance.isNotesTableEscape = false
        }

        let tags = getSidebarTags()
        let hasChangedTags = tags?.count != selectedTags?.count

        let lastRow = lastSelectedRow
        lastSelectedRow = selectedRow
        selectedTags = tags

        if let view = notification.object as? NSOutlineView {
            let i = view.selectedRow

            if UserDefaultsManagement.inlineTags,
                view.item(atRow: i) as? Tag == nil,
                storage.isFinishedTagsLoading,
                isChangedSelectedProjectsState() || (lastSelectedRow != lastRow) {

                reloadTags()
            }

            if let item = view.item(atRow: i) as? SidebarItem {
                if UserDefaultsManagement.lastSidebarItem == item.type.rawValue
                    && !hasChangedTags && !isFirstLaunch {
                    return
                }

                UserDefaultsManagement.lastSidebarItem = item.type.rawValue
                UserDefaultsManagement.lastProjectURL = nil
            }

            if let selectedProject = view.item(atRow: i) as? Project {
                if UserDefaultsManagement.lastProjectURL == selectedProject.url && !hasChangedTags && !isFirstLaunch {
                    return
                }

                UserDefaultsManagement.lastProjectURL = selectedProject.url
                UserDefaultsManagement.lastSidebarItem = nil
            }

            if !UserDataService.instance.firstNoteSelection {
                vd.editArea.clear()
                vd.notesTableView.deselectAll(nil)
            }

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
                        vd.notesTableView.saveNavigationHistory(note: lastNote)
                        vd.notesTableView.selectRow(i)

                        DispatchQueue.main.async {
                            vd.notesTableView.scrollRowToVisible(i)
                        }
                    }

                    self.isFirstLaunch = false
                }

                if let note = self.selectNote {
                    DispatchQueue.main.async {
                        self.selectNote = nil
                        vd.notesTableView.setSelected(note: note)
                    }
                } else if UserDataService.instance.firstNoteSelection {
                    if let note = vd.notesTableView.noteList.first {
                        DispatchQueue.main.async {
                            vd.selectNullTableRow(note: note)
                            vd.editArea.fill(note: note)
                        }
                    }

                    UserDataService.instance.firstNoteSelection = false
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
        guard let project = getSelectedProject() else { return }

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.url.path)
    }
    
    @IBAction func renameFolderMenu(_ sender: Any) {
        guard let vc = ViewController.shared(),
              let sidebarOutlineView = vc.sidebarOutlineView,
              sidebarOutlineView.getSelectedProject() != nil else { return }

        guard let projectRow = sidebarOutlineView.rowView(atRow: sidebarOutlineView.selectedRow, makeIfNecessary: false),
              let cell = projectRow.view(atColumn: 0) as? SidebarCellView else { return }
        
        cell.label.isEditable = true
        cell.label.becomeFirstResponder()
    }
    
    @IBAction func deleteMenu(_ sender: Any) {
        guard let vc = ViewController.shared(),
              let sidebarOutlineView = vc.sidebarOutlineView,
              let project = sidebarOutlineView.getSelectedProject() else { return }

        if !project.isRoot {
            guard let w = sidebarOutlineView.superview?.window else {
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
                    do {
                        try FileManager.default.removeItem(at: project.url)
                    } catch {
                        print(error)
                    }
                }
            }
            return
        }

        let projects = storage.getAvailableProjects().filter({ $0.url.path.starts(with: project.url.path) })

        for item in projects {
            SandboxBookmark().removeBy(item.url)
            sidebarOutlineView.removeProject(project: item)
        }

        selectRowIndexes([0], byExtendingSelection: false)
        vc.notesTableView.reloadData()
    }

    @IBAction func addProject(_ sender: Any) {
        guard let vc = ViewController.shared(),
              let sidebarOutlineView = vc.sidebarOutlineView else { return }

        var project = sidebarOutlineView.getSelectedProject()

        if sender is NSMenuItem,
            let mi = sender as? NSMenuItem,
            mi.title == NSLocalizedString("Attach storage...", comment: "") {
            project = nil
        }
        
        if sender is SidebarCellView, let cell = sender as? SidebarCellView {
            if let objectProject = cell.objectValue as? Project {
                project = objectProject
            } else {
                addRoot()
                return
            }
        }
        
        guard let project = project else {
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
                let name = field.stringValue
                self.createProject(name: name, parent: project)
            }
        }
        
        field.becomeFirstResponder()
    }

    @IBAction func openSettings(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }

        vc.openProjectViewSettings(sender)
    }

    public func removeProject(project: Project) {
        guard storage.projectExist(url: project.url) else { return }

        selectedProjects.removeAll(where: { $0 === project })

        if UserDataService.instance.lastProject?.path == project.url.path {
            self.viewDelegate?.cleanSearchAndEditArea()

            selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        self.storage.removeBy(project: project)

        if let parent = project.parent {
            if let index = parent.child.firstIndex(of: project) {
                parent.child.removeAll(where: { $0 == project })

                removeItems(at: [index], inParent: parent, withAnimation: .effectFade)
                reloadItem(parent)
            }
        } else {
            let i = row(forItem: project)
            if i > -1 {
                sidebarItems?.remove(at: i)
                removeItems(at: [i], inParent: nil, withAnimation: .effectFade)
            }
        }
    }

    public func insertProject(url: URL) {
        guard !storage.projectExist(url: url) else { return }

        guard let parent = storage.findParent(url: url) else { return }
        let project = Project(storage: storage, url: url, parent: parent)
        parent.child.insert(project, at: 0)

        storage.assignTree(for: project)

        let notes = project.fetchNotes()
        for note in notes {
            note.forceLoad()
        }

        storage.noteList.append(contentsOf: notes)
        insertItems(at: [0], inParent: parent, withAnimation: .effectFade)

        viewDelegate?.fsManager?.reloadObservedFolders()
    }
    
    public func createProject(name: String, parent: Project) {
        guard name.count > 0 else { return }
        
        do {
            let projectURL = parent.url.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: false, attributes: nil)
            
            let project = Project(storage: storage, url: projectURL, parent: parent)

            storage.assignTree(for: project)

            parent.child.insert(project, at: 0)
            insertItems(at: [0], inParent: parent, withAnimation: .effectFade)

            viewDelegate?.fsManager?.reloadObservedFolders()

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
                
                let newProject =
                    Project(
                        storage: self.storage,
                        url: url,
                        isRoot: true
                    )
                
                self.storage.assignTree(for: newProject) { projects in
                    for project in projects {
                        self.storage.loadLabel(project)
                    }

                    self.reloadSidebar(reloadManager: true)
                }
            }
        }
    }

    public func getSidebarProjects() -> [Project]? {
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return nil }

        var projects = [Project]()
        for i in v.selectedRowIndexes {
            if let si = item(atRow: i) as? SidebarItem, let project = si.project, si.tag == nil {
                projects.append(project)
            }
        }

        for i in v.selectedRowIndexes {
            if let project = item(atRow: i) as? Project {
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
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return nil }

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

    public func selectNext() {
        let i = selectedRow + 1
        guard let si = sidebarItems, si.indices.contains(i) else { return }

        if let next = si[i] as? SidebarItem {
            if next.type == .Label && next.project == nil {
                let j = i + 1

                guard let si = sidebarItems, si.indices.contains(j) else { return }

                if let next = si[j] as? SidebarItem, next.type != .Label {
                    selectRowIndexes([j], byExtendingSelection: false)
                    return
                }

                return
            }
        }

        selectRowIndexes([i], byExtendingSelection: false)
    }

    public func selectPrev() {
        let i = selectedRow - 1
        guard let si = sidebarItems, si.indices.contains(i) else { return }

        if let next = si[i] as? SidebarItem {
            if next.type == .Label && next.project == nil {
                let j = i - 1

                guard let si = sidebarItems, si.indices.contains(j) else { return }

                if let next = si[j] as? SidebarItem, next.type != .Label {
                    selectRowIndexes([j], byExtendingSelection: false)
                    return
                }

                return
            }
        }

        selectRowIndexes([i], byExtendingSelection: false)
    }

    private func getSelectedProject() -> Project? {
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return nil }

        if let project = v.item(atRow: v.selectedRow) as? Project {
            return project
        }

        if let sidebarItem = v.item(atRow: v.selectedRow) as? SidebarItem, let project = sidebarItem.project {
            return project
        }

        return nil
    }
    
    @objc public func reloadSidebar(reloadManager: Bool = false) {
        guard let vc = ViewController.shared() else { return }

        if reloadManager {
            vc.fsManager?.restart()
        } else {
            vc.fsManager?.reloadObservedFolders()
        }

        vc.loadMoveMenu()

        let selected = vc.sidebarOutlineView.selectedRow
        vc.sidebarOutlineView.sidebarItems = Sidebar().getList()
        vc.sidebarOutlineView.reloadData()
        vc.sidebarOutlineView.selectRowIndexes([selected], byExtendingSelection: false)

        vc.sidebarOutlineView.loadAllTags()
    }
        
    public func selectTag(item: Tag) {
        let i = self.row(forItem: item)
        guard i > -1 else { return }

        if let row = self.rowView(atRow: i, makeIfNecessary: true), let cell = row.view(atColumn: 0) as? SidebarCellView {
            cell.icon.image = NSImage(named: "tag_red.png")
        }
    }
    
    public func deselectTag(item: Tag) {
        let i = self.row(forItem: item)
        guard i > -1 else { return }

        if let row = self.rowView(atRow: i, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarCellView {
            cell.icon.image = NSImage(named: "tag")
        }
    }
    
    public func deselectAllTags() {
        guard let items = self.sidebarItems?.filter({($0 as? Tag) != nil}) else { return }
        for item in items {
            let i = self.row(forItem: item)
            guard i > -1 else { continue }

            if let row = self.rowView(atRow: i, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarCellView {
                cell.icon.image = NSImage(named: "tag")
            }
        }
    }

    public func selectArchive() {
        if let i = sidebarItems?.firstIndex(where: {($0 as? SidebarItem)?.type == .Archive }) {
            selectRowIndexes([i], byExtendingSelection: false)
        }
    }

    public func select(note: Note) {
        if let i = sidebarItems?.firstIndex(where: {($0 as? SidebarItem)?.project == note.project }) {
            selectNote = note
            selectRowIndexes([i], byExtendingSelection: false)
        }
    }
    
    public func remove(tag: Tag) {
        if let i = sidebarItems?.firstIndex(where: { ($0 as? Tag) === tag }) {
            self.removeItems(at: [i], inParent: nil, withAnimation: .effectFade)
            sidebarItems?.remove(at: i)
        }
    }

    public func remove(tagName: String) {
        let tags = tagName.components(separatedBy: "/")
        guard let parent = tags.first else { return }

        if let tag = sidebarItems?.first(where: {($0 as? Tag)?.getName() == parent }) as? Tag {
            if tags.count == 1 {
                let allTags = ViewController.shared()?.sidebarOutlineView.getAllTags()
                let count = allTags?.filter({ $0.starts(with: parent + "/") || $0 == parent }).count ?? 0

                if count == 0 {
                    let i = row(forItem: tag)
                    guard i > -1 else { return }

                    if let ind = sidebarItems?.indices, ind.contains(i) {
                        removeItems(at: [i], inParent: nil, withAnimation: .effectFade)
                        sidebarItems?.remove(at: i)
                    }
                }
            } else if var foundTag = tag.find(name: tagName) {
                while let parent = foundTag.getParent() {
                    if let i = parent.indexOf(child: foundTag) {
                        removeItems(at: [i], inParent: parent, withAnimation: .effectFade)
                        parent.remove(by: i)
                    }

                    if
                        parent.getParent() == nil
                        && parent.child.count == 0,
                        let i = sidebarItems?.firstIndex(where: { ($0 as? Tag)?.getName() == parent.getName() })
                    {
                        if isAllowTagRemoving(parent.getName()) {
                            removeItems(at: [i], inParent: nil, withAnimation: .effectFade)
                            sidebarItems?.remove(at: i)
                        }

                        break
                    }

                    foundTag = parent
                }
            }
        }
    }

    public func addTags(_ tags: [String], shouldUnloadOld: Bool = false) {
        self.beginUpdates()

        if shouldUnloadOld {
            unloadAllTags()
        }

        for tag in tags {

            var subtags = tag.components(separatedBy: "/")

            if let first = subtags.first,
                var tag = sidebarItems?.first(where: { ($0 as? Tag)?.getName() == first }) as? Tag {

                if subtags.count == 1 {
                    continue
                }
                
                while subtags.count > 0 {
                    subtags = Array(subtags.dropFirst())
                    
                    tag.addChild(name: subtags.joined(separator: "/"), completion: { (tagItem, isExist) in
                        tag = tagItem

                        if !isExist, let parent = tagItem.getParent() {
                            let count = parent.child.count - 1
                            self.insertItems(at: [count], inParent: tagItem.getParent(), withAnimation: .slideDown)
                        }
                    })

                    if subtags.count == 1 {
                        break
                    }
                }
            } else {
                let position = sidebarItems?.count ?? 0
                let rootTag = Tag(name: tag)
                sidebarItems?.append(rootTag)
                self.insertItems(at: [position], inParent: nil, withAnimation: .effectFade)
            }
        }
        self.endUpdates()

        checkTagsHeaderState()
    }
    
    public func removeTags(_ tags: [String]) {
        var removeTags = [String]()

        for tag in tags {
            if isAllowTagRemoving(tag) {
                removeTags.append(tag)
            }
        }

        beginUpdates()
        for tag in removeTags {
            remove(tagName: tag)
        }
        endUpdates()

        checkTagsHeaderState()
    }

    public func isAllowTagRemoving(_ name: String) -> Bool {
        let tags = getAllTags()
        var allow = true

        for tag in tags {
            if tag.starts(with: name + "/") || tag == name {
                allow = false
            }
        }

        return allow
    }

    public func reloadTags() {
        if UserDefaultsManagement.inlineTags {
            loadAllTags()
        }
    }

    public func unloadAllTags() {
        if let tags = sidebarItems?.filter({ ($0 as? Tag) != nil && ($0 as? Tag)?.getParent()
             == nil }) as? [Tag] {
            beginUpdates()
            for tag in tags {
                remove(tag: tag)
            }
            endUpdates()
        }
    }

    public func getAllTags() -> [String] {
        var tags: Set<String> = []
        var projects: [Project]? = nil

        if let item = item(atRow: selectedRow) as? SidebarItem, item.type == .All {
            projects = storage.getProjects().filter({ !$0.isTrash && !$0.isArchive })
        } else {
            projects = getSidebarProjects()
        }

        if let projects = projects {
            for project in projects {
                let projectTags = project.getAllTags()
                for tag in projectTags {
                    if !tags.contains(tag) {
                        tags.insert(tag)
                    }
                }
            }
        }

        return Array(tags)
    }

    private func loadAllTags() {
        let tags = getAllTags()

        if tags.count > 0 {
            showTagsHeader()
        } else {
            hideTagsHeader()
        }

        addTags(tags.sorted(), shouldUnloadOld: true)
    }

    private func checkTagsHeaderState() {
        let qty = sidebarItems?.filter({ ($0 as? Tag) != nil }).count ?? 0

        if qty > 0 {
            showTagsHeader()
        } else {
            hideTagsHeader()
        }
    }

    private func showTagsHeader() {
        let localized = NSLocalizedString("Tags", comment: "Sidebar label")

        if let item = sidebarItems?.first(where: {($0 as? SidebarItem)?.name == localized}) as? SidebarItem {
            let index = self.row(forItem: item)
            if index > -1, let row = self.rowView(atRow: index, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarHeaderCellView {
                cell.isHidden = false
            }
        }
    }

    public func hideTagsHeader() {
        let localized = NSLocalizedString("Tags", comment: "Sidebar label")

        if let item = sidebarItems?.first(where: {($0 as? SidebarItem)?.name == localized}) as? SidebarItem {
            let index = self.row(forItem: item)
            if index > -1, let row = self.rowView(atRow: index, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarHeaderCellView {
                cell.isHidden = true
            }
        }
    }

    public func select(tag: String) {
        let fullTags = tag.split(separator: "/").map(String.init);
        var items = sidebarItems;
        var tagDepth:Int = 0;
        var tagIndexArr = [Int]();
        for tagIndex in 0..<fullTags.count{
            guard let index = items?.firstIndex(where: {($0 as? Tag)?.getName() == fullTags[tagIndex]}) else { break }
            items = (items?[index] as? Tag)?.child;
            tagDepth += tagIndex == 0 ? index : index+1;
            tagIndexArr.append(tagDepth)
        }

        UserDataService.instance.firstNoteSelection = true
        selectRowIndexes([tagDepth], byExtendingSelection: false, tagIndexArr)
    }
        
    // select and open rowIndexes
    func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool, _ tagIndexArr : [Int]) {
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

        tagIndexArr.forEach { tagIndex in
            self.expandItem(item(atRow: tagIndex))
        }

        super.selectRowIndexes(indexes, byExtendingSelection: extend)
    }
}
