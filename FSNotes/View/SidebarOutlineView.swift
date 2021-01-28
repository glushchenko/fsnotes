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

        guard let sidebarItem = getSidebarItem() else { return false }

        if id == "folderMenu.backup" {

            if sidebarItem.isTrash() || sidebarItem.tag != nil {
                return false
            }

            return true
        }

        if id == "folderMenu.reveal" {
            if let sidebarItem = getSidebarItem() {
                return sidebarItem.project != nil || sidebarItem.isTrash()
            }
        }

        if id == "folderMenu.rename" {
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

        if id == "folderMenu.delete" {
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

        if id == "folderMenu.options" {
            if sidebarItem.isTrash() {
                return false
            }

            return nil != sidebarItem.project
        }

        if id == "folderMenu.new" {
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

                guard let tag = item(atRow: selectedRow) as? Tag, tag.isExpandable() else {
                    vc.notesTableView.selectNext()
                    NSApp.mainWindow?.makeFirstResponder(vc.notesTableView)
                    return
                }
            }
        }

        super.keyDown(with: event)
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let vc = ViewController.shared() else { return false }
        let board = info.draggingPasteboard

        var urls = [URL]()
        if let data = info.draggingPasteboard.data(forType: NSPasteboard.noteType),
           let unarchivedData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [URL] {
            urls = unarchivedData
        }

        if !UserDefaultsManagement.inlineTags,
            let sidebarItem = item as? Tag,
            urls.count > 0,
            Storage.sharedInstance().getBy(url: urls.first!) != nil {

            for url in urls {
                if let note = Storage.sharedInstance().getBy(url: url) {
                    note.addTag(sidebarItem.getName())
                    selectTag(item: sidebarItem)
                }
            }

            return true
        }

        guard let sidebarItem = item as? SidebarItem else { return false }

        switch sidebarItem.type {
        case .Label, .Category, .Trash, .Archive, .Inbox:

            if urls.count > 0, Storage.sharedInstance().getBy(url: urls.first!) != nil {

                var notes = [Note]()
                for url in urls {
                    if let note = Storage.sharedInstance().getBy(url: url) {
                        notes.append(note)
                    }
                }

                if let project = sidebarItem.project {
                    vc.move(notes: notes, project: project)
                } else if sidebarItem.isTrash() {
                    vc.editArea.clear()
                    vc.storage.removeNotes(notes: notes) { _ in
                        DispatchQueue.main.async {
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
        default:
            break
        }

        return false
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

        guard let sidebarItem = item as? SidebarItem else { return NSDragOperation() }
        switch sidebarItem.type {
        case .Trash:
            if isLocalNote {
                return .copy
            }
            break
        case .Category, .Label, .Archive, .Inbox:
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
                cell.icon.image = NSImage(imageLiteralResourceName: "trashBin")
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

        guard let sidebarItems = sidebarItems else { return }

        let tags = getSidebarTags()
        let hasChangedTags = tags?.count != selectedTags?.count

        let lastRow = lastSelectedRow
        lastSelectedRow = selectedRow
        selectedTags = tags

        if let view = notification.object as? NSOutlineView {
            let sidebar = sidebarItems
            let i = view.selectedRow

            if let cell = view.item(atRow: i) as? SidebarItem {
                let isTag = cell.type == .Tag
                if UserDefaultsManagement.inlineTags, isChangedSelectedProjectsState() || (lastSelectedRow != lastRow && !isTag) {

                    if storage.isFinishedTagsLoading {
                        reloadTags()
                    }
                }
            }
            
            if sidebar.indices.contains(i), let item = sidebar[i] as? SidebarItem {
                if UserDataService.instance.lastType == item.type.rawValue && UserDataService.instance.lastProject == item.project?.url &&
                    UserDataService.instance.lastName == item.name &&
                    !hasChangedTags {
                    return
                }

                UserDefaultsManagement.lastProject = i

                UserDataService.instance.lastType = item.type.rawValue
                UserDataService.instance.lastProject = item.project?.url
                UserDataService.instance.lastName = item.name
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
                    } else if vd.notesTableView.noteList.count > 0 {
                        vd.focusTable()
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
        guard let si = getSidebarItem(), let p = si.project else { return }

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: p.url.path)
    }
    
    @IBAction func renameFolderMenu(_ sender: Any) {
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return }
        
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
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return }
        
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
                    do {
                        try FileManager.default.removeItem(at: project.url)
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
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return }
        
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

        if let si = sidebarItems?.first(where: { ($0 as? SidebarItem)?.project === project }) {
            let i = row(forItem: si)
            guard i > -1 else { return }

            sidebarItems?.remove(at: i)
            removeItems(at: [i], inParent: nil, withAnimation: .effectFade)
        }
    }

    public func insertProject(url: URL) {
        guard !storage.projectExist(url: url) else { return }

        guard let parent = self.storage.getProjects().first(where: { $0.isRoot && url.path.contains($0.url.path) }) else { return }

        let newProject =
            Project(
                storage: self.storage,
                url: url,
                parent: parent
            )

        self.storage.assignTree(for: newProject)

        let notes = newProject.fetchNotes()
        for note in notes {
            note.forceLoad()
        }
        self.storage.noteList.append(contentsOf: notes)

        let list = Sidebar().getList()
        if let index = list.firstIndex(where: { ($0 as? SidebarItem)?.project === newProject }) {
            sidebarItems = list
            let set = IndexSet(integer: index)
            insertItems(at: set, inParent: nil, withAnimation: .effectFade)
        }

        viewDelegate?.fsManager?.reloadObservedFolders()
    }
    
    public func createProject(name: String, parent: Project) {
        guard name.count > 0 else { return }
        
        do {
            let projectURL = parent.url.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: false, attributes: nil)
            
            let newProject =
                Project(
                    storage: storage,
                    url: projectURL,
                    parent: parent.getParent()
                )
            storage.assignTree(for: newProject)
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

                if let next = si[j] as? SidebarItem, next.type != .Tag && next.type != .Label {
                    selectRowIndexes([j], byExtendingSelection: false)
                    return
                }

                return
            }

            if next.type == .Tag {
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

                if let next = si[j] as? SidebarItem, next.type != .Tag && next.type != .Label {
                    selectRowIndexes([j], byExtendingSelection: false)
                    return
                }

                return
            }

            if next.type == .Tag {
                return
            }
        }

        selectRowIndexes([i], byExtendingSelection: false)
    }

    private func getSidebarItem() -> SidebarItem? {
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return nil }
        
        let selected = v.selectedRow
        guard let si = v.sidebarItems,
            si.indices.contains(selected) else { return nil }
        
        let sidebarItem = si[selected] as? SidebarItem
        return sidebarItem
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
            cell.icon.image = NSImage(named: "tag.png")
        }
    }
    
    public func deselectAllTags() {
        guard let items = self.sidebarItems?.filter({($0 as? Tag) != nil}) else { return }
        for item in items {
            let i = self.row(forItem: item)
            guard i > -1 else { continue }

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
                        && parent.getChild().count == 0,
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
                            let count = parent.getChild().count - 1
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

        if let item = getSidebarItem(), item.type == .All {
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

        if let item = sidebarItems?.first(where: {($0 as? SidebarItem)?.name == "# \(localized)"}) as? SidebarItem {
            let index = self.row(forItem: item)
            if index > -1, let row = self.rowView(atRow: index, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarHeaderCellView {
                cell.isHidden = false
            }
        }
    }

    public func hideTagsHeader() {
        let localized = NSLocalizedString("Tags", comment: "Sidebar label")

        if let item = sidebarItems?.first(where: {($0 as? SidebarItem)?.name == "# \(localized)"}) as? SidebarItem {
            let index = self.row(forItem: item)
            if index > -1, let row = self.rowView(atRow: index, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarHeaderCellView {
                cell.isHidden = true
            }
        }
    }

    public func select(tag: String) {
        guard let i = sidebarItems?.firstIndex(where: {($0 as? Tag)?.getName() == tag }) else { return }

        UserDataService.instance.firstNoteSelection = true
        selectRowIndexes([i], byExtendingSelection: false)
    }
}
