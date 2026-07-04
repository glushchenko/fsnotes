//
//  SidebarTableView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 5/5/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

import UIKit
import AudioToolbox

class SidebarTableView: UITableView,
    UITableViewDelegate,
    UITableViewDataSource,
    UITableViewDropDelegate {

    public var sidebar = Sidebar()
    private var allTagNames = Set<String>()
    private var busyTrashReloading = false
    public var viewController: ViewController?

    func numberOfSections(in tableView: UITableView) -> Int {
        return sidebar.items.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sidebar.items[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "sidebarCell", for: indexPath) as! SidebarTableCellView

        guard sidebar.items.indices.contains(indexPath.section), sidebar.items[indexPath.section].indices.contains(indexPath.row) else { return cell }

        let sidebarItem = sidebar.items[indexPath.section][indexPath.row]
        cell.configure(sidebarItem: sidebarItem)
        cell.onDisclosureToggle = { [weak self] project in
            self?.toggleDisclosure(for: project)
        }
        cell.onTagDisclosureToggle = { [weak self] tag in
            self?.toggleDisclosure(for: tag)
        }
        cell.contentView.setNeedsLayout()
        cell.contentView.layoutIfNeeded()

        return cell
    }

    private func toggleDisclosure(for project: Project) {
        let selectedProject = getSelectedSidebarItem()?.project
        let projectsSection = SidebarSection.Projects.rawValue
        let oldItems = sidebar.items[projectsSection]
        let oldURLs = Set(oldItems.compactMap { $0.project?.url })

        project.isExpanded.toggle()
        Storage.shared().saveProjectsExpandState()
        sidebar.reloadProjects()
        let newItems = sidebar.items[projectsSection]
        let newURLs = Set(newItems.compactMap { $0.project?.url })

        let deleted = oldItems.enumerated().compactMap { index, item -> IndexPath? in
            guard let url = item.project?.url, !newURLs.contains(url) else { return nil }
            return IndexPath(row: index, section: projectsSection)
        }
        let inserted = newItems.enumerated().compactMap { index, item -> IndexPath? in
            guard let url = item.project?.url, !oldURLs.contains(url) else { return nil }
            return IndexPath(row: index, section: projectsSection)
        }

        performBatchUpdates {
            if !deleted.isEmpty {
                deleteRows(at: deleted, with: .fade)
            }
            if !inserted.isEmpty {
                insertRows(at: inserted, with: .fade)
            }
        } completion: { [weak self] _ in
            guard let self = self else { return }

            if let projectPath = self.getIndexPathBy(project: project) {
                self.reloadRows(at: [projectPath], with: .none)
            }

            if let selectedProject = selectedProject,
               let selectedPath = self.getIndexPathBy(project: selectedProject) {
                self.selectRow(at: selectedPath, animated: false, scrollPosition: .none)
            }

            self.viewController?.resizeSidebar(withAnimation: true)
        }
    }

    private func toggleDisclosure(for tag: FSTag) {
        let tagsSection = SidebarSection.Tags.rawValue
        let tagName = tag.getFullName()
        let selectedTag = viewController?.storage.searchQuery.tags.first
        let oldItems = sidebar.items[tagsSection]
        let oldNames = Set(oldItems.map { $0.name })
        var expanded = Set(UserDefaultsManagement.expandedSidebarTags)

        if expanded.contains(tagName) {
            expanded.remove(tagName)
        } else {
            expanded.insert(tagName)
        }
        UserDefaultsManagement.expandedSidebarTags = Array(expanded).sorted()

        rebuildTagItems()
        let newItems = sidebar.items[tagsSection]
        let newNames = Set(newItems.map { $0.name })
        let deleted = oldItems.enumerated().compactMap { index, item in
            newNames.contains(item.name) ? nil : IndexPath(row: index, section: tagsSection)
        }
        let inserted = newItems.enumerated().compactMap { index, item in
            oldNames.contains(item.name) ? nil : IndexPath(row: index, section: tagsSection)
        }

        performBatchUpdates {
            if !deleted.isEmpty {
                deleteRows(at: deleted, with: .fade)
            }
            if !inserted.isEmpty {
                insertRows(at: inserted, with: .fade)
            }
        } completion: { [weak self] _ in
            guard let self = self else { return }

            if let tagPath = self.getIndexPathBy(tag: tagName) {
                self.reloadRows(at: [tagPath], with: .none)
            }
            if let selectedTag = selectedTag,
               let selectedPath = self.getIndexPathBy(tag: selectedTag) {
                self.selectRow(at: selectedPath, animated: false, scrollPosition: .none)
            }

            self.viewController?.resizeSidebar(withAnimation: true)
        }
    }

    private func rebuildTagItems() {
        let tagsSection = SidebarSection.Tags.rawValue
        guard sidebar.items.indices.contains(tagsSection) else { return }

        var roots = [FSTag]()

        func insert(_ components: ArraySlice<String>, parent: FSTag?) {
            guard let name = components.first else { return }
            let siblings = parent?.child ?? roots
            let tag: FSTag

            if let existing = siblings.first(where: { $0.name == name }) {
                tag = existing
            } else {
                tag = FSTag(name: name, parent: parent)
                if let parent = parent {
                    parent.child.append(tag)
                    parent.child.sort {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                } else {
                    roots.append(tag)
                }
            }

            insert(components.dropFirst(), parent: tag)
        }

        for fullName in allTagNames.sorted() {
            let components = fullName.split(separator: "/").map(String.init)
            insert(components[...], parent: nil)
        }

        roots.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let expanded = Set(UserDefaultsManagement.expandedSidebarTags)
        var items = [SidebarItem]()

        func append(_ tag: FSTag) {
            let fullName = tag.getFullName()
            tag.isExpanded = expanded.contains(fullName)
            items.append(SidebarItem(name: fullName, type: .Tag, tag: tag))

            if tag.isExpanded {
                tag.child.forEach(append)
            }
        }

        roots.forEach(append)
        sidebar.items[tagsSection] = items
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            return UIView()
        }

        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 5
        }

        if section == 1 && UIApplication.getVC().storage.getNonSystemProjects().count == 0 {
            return 0
        }

        return 25
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 37
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        selectRow(at: indexPath, animated: false, scrollPosition: .none)

        self.tableView(tableView, didSelectRowAt: indexPath)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let vc = self.viewController else { return }
        let selectedSection = SidebarSection(rawValue: indexPath.section)

        guard sidebar.items.indices.contains(indexPath.section) && sidebar.items[indexPath.section].indices.contains(indexPath.row) else { return }

        let sidebarItem = sidebar.items[indexPath.section][indexPath.row]

        guard vc.storage.searchQuery.projects.first != sidebarItem.project
            || sidebarItem.type == .Tag else { return }

        if let project = vc.storage.searchQuery.projects.first, getIndexPathBy(project: project) == indexPath, vc.notesTable.isEditing {
            vc.notesTable.toggleSelectAll()
            return
        }

        if let project = sidebarItem.project, project.isLocked() {
            vc.enableLockedProject()
        } else {
            vc.disableLockedProject()
        }

        guard sidebar.items.indices.contains(indexPath.section) && sidebar.items[indexPath.section].indices.contains(indexPath.row) else {
            return
        }

        vc.notesTable.turnOffEditing()

        var name = sidebarItem.name
        if sidebarItem.type == .Tag {
            name = "#\(name)"
        }

        if selectedSection == .Tags {
            deselectAllTags()
        } else {
            deselectAllProjects()
            deselectAllTags()
        }

        selectRow(at: indexPath, animated: false, scrollPosition: .none)
        vc.configureNavMenu(for: sidebarItem)
        vc.navigationItem.searchController?.searchBar.text = ""

        // Save last state
        
        if sidebarItem.isSystem() {
            UserDefaultsManagement.lastSidebarItem = indexPath.row
            UserDefaultsManagement.lastProjectURL = nil
        } else if let project = sidebarItem.project, !project.isVirtual {
            UserDefaultsManagement.lastSidebarItem = nil
            UserDefaultsManagement.lastProjectURL = project.url
        }

        vc.buildSearchQuery()
        vc.reloadNotesTable() {
            DispatchQueue.main.async {
                vc.notesTable.hideLoader()
                vc.setNavTitle(folder: name)
                vc.isLoadedSidebar = true

                guard vc.notesTable.notes.count > 0 else {
                    self.unloadAllTags()
                    return
                }

                let path = IndexPath(row: 0, section: 0)
                vc.notesTable.scrollToRow(at: path, at: .top, animated: true)

                if selectedSection != .Tags {
                    self.loadAllTags()
                    vc.resizeSidebar(withAnimation: true)
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let sidebarItem = self.sidebar.items[indexPath.section][indexPath.row]
            let menu = self.viewController!.makeSidebarSettingsMenu(for: sidebarItem)
            return menu
        }
    }

    public func selectCurrentProject() {
        guard let vc = self.viewController else { return }

        var indexPath: IndexPath = IndexPath(row: 0, section: 0)
        if let type = vc.storage.searchQuery.type,
            let ip = getIndexPathBy(type: type) {
            indexPath = ip
        } else if let project = vc.storage.searchQuery.projects.first,
            let ip = getIndexPathBy(project: project) {
            indexPath = ip
        }

        let sidebarItem = sidebar.items[indexPath.section][indexPath.row]
        let name = sidebarItem.name

        selectRow(at: indexPath, animated: false, scrollPosition: .none)

        vc.configureNavMenu(for: sidebarItem)
        vc.buildSearchQuery()
        vc.reloadNotesTable() {
            DispatchQueue.main.async {
                vc.setNavTitle(folder: name)
            }
        }
    }

    private func deselectAllTags() {
        if let selectedIndexPaths = indexPathsForSelectedRows {
            for indexPathItem in selectedIndexPaths {
                if indexPathItem.section == SidebarSection.Tags.rawValue {
                    deselectRow(at: indexPathItem, animated: false)
                }
            }
        }
    }

    private func deselectAllProjects() {
        if let selectedIndexPaths = indexPathsForSelectedRows {
            for indexPathItem in selectedIndexPaths {
                if indexPathItem.section == SidebarSection.Projects.rawValue
                    || indexPathItem.section == SidebarSection.System.rawValue {
                    deselectRow(at: indexPathItem, animated: false)
                }
            }
        }

    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor.clear
    }

    public func deselectAll() {
        if let paths = indexPathsForSelectedRows {
            for path in paths {
                deselectRow(at: path, animated: false)
            }
        }
    }

    public func getSidebarItem(project: Project? = nil) -> SidebarItem? {

        if let project = project, sidebar.items.count > 1 {
            return sidebar.items[1].first(where: { $0.project == project })
        }

        guard let indexPath = indexPathForSelectedRow else { return nil }

        let item = sidebar.items[indexPath.section][indexPath.row]

        return item
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {

        guard let vc = viewController else { return }
        guard let indexPath = coordinator.destinationIndexPath, let cell = tableView.cellForRow(at: indexPath) as? SidebarTableCellView else { return }

        guard let sidebarItem = cell.sidebarItem else { return }

        _ = coordinator.session.loadObjects(ofClass: URL.self) { item in
            let pathList = item as [URL]

            for url in pathList {
                guard let note = Storage.shared().getBy(url: url) else { continue }

                switch sidebarItem.type {
                case .Project, .Inbox:
                    guard let project = sidebarItem.project else { break }
                    self.move(note: note, in: project)
                case .Trash:
                    note.remove()
                    vc.notesTable.removeRows(notes: [note])
                default:
                    break
                }
            }

            vc.notesTable.isEditing = false
            vc.navigationController?.setToolbarHidden(true, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {

        guard let indexPath = destinationIndexPath,
            let cell = tableView.cellForRow(at: indexPath) as? SidebarTableCellView,
            let sidebarItem = cell.sidebarItem
        else { return UITableViewDropProposal(operation: .cancel) }

        if sidebarItem.project != nil || sidebarItem.type == .Trash {
            return UITableViewDropProposal(operation: .copy)
        }

        return UITableViewDropProposal(operation: .cancel)
    }

    private func move(note: Note, in project: Project) {
        guard let vc = viewController else { return }

        let dstURL = project.url.appendingPathComponent(note.name)

        if note.project != project {
            note.moveImages(to: project)

            if note.isEncrypted() {
                _ = note.lock()
            }

            guard note.move(to: dstURL) else {
                let alert = UIAlertController(title: "Oops 👮‍♂️", message: "File with this name already exist", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                vc.present(alert, animated: true, completion: nil)

                note.moveImages(to: note.project)
                return
            }

            note.moveHistory(src: note.url, dst: dstURL)

            note.url = dstURL
            note.parseURL()
            note.project = project

            // resets tags in sidebar
            removeTags(in: [note])

            // reload tags (in remove tags operation non fitted)
            _ = note.scanContentTags()

            vc.notesTable.removeRows(notes: [note])
            vc.notesTable.insertRows(notes: [note])
        }
    }

    public func getSidebarProjects() -> [Project]? {
        guard let indexPaths = UIApplication.getVC().sidebarTableView?.indexPathsForSelectedRows else { return nil }

        var projects = [Project]()
        for indexPath in indexPaths {
            let item = sidebar.items[indexPath.section][indexPath.row]
            if let project = item.project {
                projects.append(project)
            }
        }

        if projects.count > 0 {
            return projects
        }

        if let root = Storage.shared().getDefault() {
            return [root]
        }

        return nil
    }

    public func getAllTags(projects: [Project]? = nil) -> [String] {
        var tags = [String]()

        if let projects = projects {
            for project in projects {
                let projectTags = project.getAllTags()
                for tag in projectTags {
                    if !tags.contains(tag) {
                        tags.append(tag)
                    }
                }
            }
        }

        return tags.sorted()
    }

    private func getAllTags(notes: [Note]? = nil) -> [String] {
        var tags = [String]()

        if let notes = notes {
            for note in notes {
               for tag in note.tags {
                   if !tags.contains(tag) {
                       tags.append(tag)
                   }
               }
            }
        }

        return tags.sorted()
    }

    public func loadAllTags() {
        guard UserDefaultsManagement.inlineTags, let vc = viewController else { return }

        unloadAllTags()

        let notes = vc.notesTable.notes
        let tags = getAllTags(notes: notes)

        guard tags.count > 0, self.sidebar.items.indices.contains(2) else { return }

        allTagNames = Set(tags)
        rebuildTagItems()
        let indexPaths = sidebar.items[2].indices.map { IndexPath(row: $0, section: 2) }

        insertRows(at: indexPaths, with: .automatic)
    }

    public func unloadAllTags() {
        guard sidebar.items.indices.contains(2), sidebar.items[2].count > 0 else { return }

        let rows = numberOfRows(inSection: 2)

        if rows > 0 {
            self.sidebar.items[2].removeAll()
            allTagNames.removeAll()

            var indexPaths = [IndexPath]()
            for index in stride(from: rows - 1, to: -1, by: -1) {
                indexPaths.append(IndexPath(row: index, section: 2))
            }

            deleteRows(at: indexPaths, with: .automatic)
        }
    }

    public func removeTags(in notes: [Note]) {
        for note in notes {
            note.tags.removeAll()
        }

        loadTags(notes: notes)
    }

    public func loadTags(notes: [Note]) {
        var toInsert = [String]()
        var toDelete = [String]()

        for note in notes {
            guard let query = createQueryWithoutTags(), query.isFit(note: note) else { continue }

            let result = note.scanContentTags()
            if result.0.count > 0 {
                toInsert.append(contentsOf: result.0)
            }

            if result.1.count > 0 {
                toDelete.append(contentsOf: result.1)
                note.tags.removeAll(where: { result.1.contains($0) })
            }
        }

        toInsert = Array(Set(toInsert))
        toDelete = Array(Set(toDelete))

        insert(tags: toInsert)
        delete(tags: toDelete)
    }

    public func insert(tags: [String]) {
        let newTags = Set(tags).subtracting(allTagNames)
        guard !newTags.isEmpty else { return }

        allTagNames.formUnion(newTags)
        rebuildTagItems()
        reloadSections(IndexSet(integer: SidebarSection.Tags.rawValue), with: .fade)
    }

    public func delete(tags: [String]) {
        guard let vc = viewController else { return }

        var allTags = [String]()

        if let project = vc.storage.searchQuery.projects.first {
            allTags = project.getAllTags()
        } else if let type = vc.storage.searchQuery.type {
            var notes = [Note]()
            switch type {
            case .All:
                notes = Storage.shared().noteList
                break
            case .Inbox:
                notes = Storage.shared().noteList.filter({ $0.project.isDefault })
                break
            case .Todo:
                notes = Storage.shared().noteList.filter({ $0.content.string.contains("- [ ] ") })
            default:
                break
            }

            for note in notes {
                allTags.append(contentsOf: note.tags)
            }
        }

        let toRemoveTags = tags.filter { !allTags.contains($0) }
        allTagNames = Set(allTags)
        rebuildTagItems()
        reloadSections(IndexSet(integer: SidebarSection.Tags.rawValue), with: .fade)

        deSelectTagIfNonExist(tags: toRemoveTags)
    }

    private func createQueryWithoutTags() -> SearchQuery? {
        guard let vc = viewController else { return nil }

        let query = SearchQuery()
        query.projects = vc.storage.searchQuery.projects

        if let type = vc.storage.searchQuery.type {
            query.type = type

            if query.projects.first != nil && type == .Tag {
                query.type = .Project
            }
        }

        return query
    }

    private func deSelectTagIfNonExist(tags: [String]) {
        guard let vc = viewController,
              let tag = vc.storage.searchQuery.tags.first
        else { return }

        guard tags.contains(tag) else { return }

        if let project = vc.storage.searchQuery.projects.first,
            let index = getIndexPathBy(project: project)
        {
            tableView(self, didSelectRowAt: index)
            return
        }

        if let type = vc.storage.searchQuery.type,
            let index = getIndexPathBy(type: type) {
            tableView(self, didSelectRowAt: index)
        }
    }

    public func getSelectedSidebarItem() -> SidebarItem? {
        guard let vc = viewController,
              let project = vc.storage.searchQuery.projects.first
        else { return nil }

        let items = sidebar.items

        for item in items {
            for subItem in item {
                if subItem.project == project {
                    return subItem
                }
            }
        }

        return nil
    }

    public func getIndexPathBy(project: Project) -> IndexPath? {
        for (sectionId, section) in sidebar.items.enumerated() {
            for (rowId, item) in section.enumerated() {
                if item.project === project {
                    let indexPath = IndexPath(row: rowId, section: sectionId)
                    return indexPath
                }
            }
        }

        return nil
    }

    public func getIndexPathBy(tag: String) -> IndexPath? {
        let tagsSection = SidebarSection.Tags.rawValue

        for (rowId, item) in sidebar.items[tagsSection].enumerated() {
            if item.name == tag {
                let indexPath = IndexPath(row: rowId, section: tagsSection)
                return indexPath
            }
        }

        return nil
    }

    public func getIndexPathBy(type: SidebarItemType) -> IndexPath? {
        let section = SidebarSection.System.rawValue

        for (rowId, item) in sidebar.items[section].enumerated() {
            if item.type == type {
                let indexPath = IndexPath(row: rowId, section: section)
                return indexPath
            }
        }

        return nil
    }

    public func insertRows(projects: [Project]) {
        guard sidebar.items.indices.contains(1) else { return }

        var selectedProject: Project?
        var selectedTag: String?
        var selectedType: SidebarItemType?
        if let selectedPath = indexPathForSelectedRow,
           sidebar.items.indices.contains(selectedPath.section),
           sidebar.items[selectedPath.section].indices.contains(selectedPath.row) {
            let selectedItem = sidebar.items[selectedPath.section][selectedPath.row]
            selectedProject = selectedItem.project
            selectedTag = selectedItem.type == .Tag ? selectedItem.name : nil
            selectedType = selectedItem.type
        }

        let existingProjects = sidebar.items[1].compactMap { $0.project }

        let toInsert = projects
            .filter { !existingProjects.contains($0) && $0.settings.showInSidebar }

        guard !toInsert.isEmpty else { return }

        sidebar.reloadProjects()
        performBatchUpdates {
            reloadSections(IndexSet(integer: SidebarSection.Projects.rawValue), with: .fade)
        } completion: { [weak self] _ in
            guard let self = self else { return }

            let restoredPath: IndexPath?
            if let selectedProject = selectedProject {
                restoredPath = self.getIndexPathBy(project: selectedProject)
            } else if let selectedTag = selectedTag {
                restoredPath = self.getIndexPathBy(tag: selectedTag)
            } else if let selectedType = selectedType {
                restoredPath = self.getIndexPathBy(type: selectedType)
            } else {
                restoredPath = nil
            }

            if let restoredPath = restoredPath {
                self.selectRow(at: restoredPath, animated: false, scrollPosition: .none)
            }

            UIApplication.getVC().resizeSidebar()
        }
    }

    
    public func removeRows(projects: [Project]) {
        guard let vc = viewController else { return }

        let toDelete: [Project] = projects.flatMap { [$0] + $0.getChildProjectsByURL() }
        guard !toDelete.isEmpty else { return }
        var deselectCurrent = false

        performBatchUpdates({
            var indexPathsToDelete = [IndexPath]()

            for index in sidebar.items[1].indices.reversed() {
                let item = sidebar.items[1][index]
                guard let project = item.project else { continue }

                if toDelete.contains(project) {
                    sidebar.items[1].remove(at: index)
                    indexPathsToDelete.append(IndexPath(row: index, section: 1))

                    if project == vc.storage.searchQuery.projects.first {
                        deselectCurrent = true
                    }

                    vc.storage.remove(project: project)
                }
            }

            if !indexPathsToDelete.isEmpty {
                deleteRows(at: indexPathsToDelete, with: .automatic)
            }
        }, completion: { _ in
            if deselectCurrent {
                vc.notesTable.notes.removeAll()
                vc.notesTable.reloadData()

                let indexPath = IndexPath(row: 0, section: 0)
                self.tableView(self, didSelectRowAt: indexPath)
            }

            UIApplication.getVC().resizeSidebar()
        })
    }

    public func select(project: Project) {
        guard let indexPath = getIndexPathBy(project: project) else { return }
        tableView(self, didSelectRowAt: indexPath)
    }

    public func select(tag: String) {
        guard let indexPath = getIndexPathBy(tag: tag) else { return }
        tableView(self, didSelectRowAt: indexPath)
    }

    public func remove(tag: String) {
        allTagNames.remove(tag)
        rebuildTagItems()
        reloadSections(IndexSet(integer: SidebarSection.Tags.rawValue), with: .automatic)

        selectCurrentProject()
    }

    public func reloadSidebar() {
        sidebar = Sidebar()
        reloadData()

        var indexPath = IndexPath(row: 0, section: 0)

        if
            let projectURL = UserDefaultsManagement.lastProjectURL,
            let project = Storage.shared().getProjectBy(url: projectURL),
            let path = getIndexPathBy(project: project) {

            indexPath = path
        } else if let rowId = UserDefaultsManagement.lastSidebarItem {
            indexPath = IndexPath(row: rowId, section: 0)
        }

        tableView(self, didSelectRowAt: indexPath)
        
        viewController?.resizeSidebar(withAnimation: true)
    }

    public func reload(indexPath: IndexPath) {
        
        // Important as cell resets after reloadRows
        let currentPath = indexPathForSelectedRow

        reloadRows(at: [indexPath], with: .automatic)
        selectRow(at: currentPath, animated: false, scrollPosition: .none)
    }
}
