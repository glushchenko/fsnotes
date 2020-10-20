//
//  SidebarTableView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 5/5/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

import UIKit
import NightNight
import AudioToolbox

@IBDesignable
class SidebarTableView: UITableView,
    UITableViewDelegate,
    UITableViewDataSource,
    UITableViewDropDelegate {

    @IBInspectable var startColor:   UIColor = .black { didSet { updateColors() }}
    @IBInspectable var endColor:     UIColor = .white { didSet { updateColors() }}
    @IBInspectable var startLocation: Double =   0.05 { didSet { updateLocations() }}
    @IBInspectable var endLocation:   Double =   0.95 { didSet { updateLocations() }}
    @IBInspectable var horizontalMode:  Bool =  false { didSet { updatePoints() }}
    @IBInspectable var diagonalMode:    Bool =  false { didSet { updatePoints() }}

    var gradientLayer: CAGradientLayer { return layer as! CAGradientLayer }
    private var sidebar: Sidebar = Sidebar()
    private var busyTrashReloading = false

    public var viewController: ViewController?

    override class var layerClass: AnyClass { return CAGradientLayer.self }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePoints()
        updateLocations()
        updateColors()
    }

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
        cell.contentView.setNeedsLayout()
        cell.contentView.layoutIfNeeded()

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ""
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 10
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            let custom = UIView()
            view.backgroundView = custom

            var font: UIFont = UIFont.systemFont(ofSize: 15)

            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .caption1)
                font = fontMetrics.scaledFont(for: font)
            }

            view.textLabel?.font = font.bold()
            view.textLabel?.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            let custom = UIView()
            view.backgroundView = custom
            
            var font: UIFont = UIFont.systemFont(ofSize: 15)
            
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .caption1)
                font = fontMetrics.scaledFont(for: font)
            }
            
            view.textLabel?.font = font.bold()
            view.textLabel?.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 37
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        selectRow(at: indexPath, animated: false, scrollPosition: .none)

        self.tableView(tableView, didSelectRowAt: indexPath)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedSection = SidebarSection(rawValue: indexPath.section)
        let sidebarItem = sidebar.items[indexPath.section][indexPath.row]

        guard sidebar.items.indices.contains(indexPath.section) && sidebar.items[indexPath.section].indices.contains(indexPath.row) else {
            return
        }

        guard let vc = self.viewController else { return }
        vc.turnOffSearch()
        vc.notesTable.turnOffEditing()

        if sidebarItem.name == NSLocalizedString("Settings", comment: "Sidebar settings") {
            Timer.scheduledTimer(withTimeInterval: 0.01, repeats: false) { _ in
                vc.openSettings()
                self.deselectRow(at: indexPath, animated: false)
            }

            AudioServicesPlaySystemSound(1519)
            return
        }

        var name = sidebarItem.name
        
        if sidebarItem.type == .Category || sidebarItem.isSystem() {
            name += " ▽"
        }

        if sidebarItem.type == .Tag {
            name = "#\(name)"
        }

        let newQuery = SearchQuery()
        newQuery.setType(sidebarItem.type)
        newQuery.project = sidebarItem.project
        newQuery.tag = nil

        if selectedSection == .Tags {
            newQuery.type = vc.searchQuery.type
            newQuery.project = vc.searchQuery.project
            newQuery.tag = sidebarItem.name

            deselectAllTags()
        } else {
            deselectAllProjects()
            deselectAllTags()
        }

        selectRow(at: indexPath, animated: false, scrollPosition: .none)

        vc.reloadNotesTable(with: newQuery) {
            DispatchQueue.main.async {
                vc.currentFolder.text = name

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

    public func selectCurrentProject() {
        guard let vc = self.viewController else { return }

        var indexPath: IndexPath = IndexPath(row: 0, section: 0)
        if let type = vc.searchQuery.type,
            let ip = getIndexPathBy(type: type) {
            indexPath = ip
        } else if let project = vc.searchQuery.project,
            let ip = getIndexPathBy(project: project) {
            indexPath = ip
        }

        let sidebarItem = sidebar.items[indexPath.section][indexPath.row]

        let name = sidebarItem.name + " ▽"
        let newQuery = SearchQuery()
        newQuery.setType(sidebarItem.type)
        newQuery.project = sidebarItem.project

        selectRow(at: indexPath, animated: false, scrollPosition: .none)

        vc.reloadNotesTable(with: newQuery) {
            DispatchQueue.main.async {
                vc.currentFolder.text = name
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
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0xffffff, night: 0xffffff)

        if let sidebarCell = cell as? SidebarTableCellView {
            if let sidebarItem = (cell as! SidebarTableCellView).sidebarItem, sidebarItem.type == .Tag || sidebarItem.type == .Category {
                sidebarCell.icon.constraints[1].constant = 0
                sidebarCell.labelConstraint.constant = 0
                sidebarCell.contentView.setNeedsLayout()
                sidebarCell.contentView.layoutIfNeeded()
            }
        }
    }

    public func deselectAll() {
        if let paths = indexPathsForSelectedRows {
            for path in paths {
                deselectRow(at: path, animated: false)
            }
        }
    }

    // MARK: Gradient settings
    func updatePoints() {
        if horizontalMode {
            gradientLayer.startPoint = diagonalMode ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint   = diagonalMode ? CGPoint(x: 0, y: 1) : CGPoint(x: 1, y: 0.5)
        } else {
            gradientLayer.startPoint = diagonalMode ? CGPoint(x: 0, y: 0) : CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint   = diagonalMode ? CGPoint(x: 1, y: 1) : CGPoint(x: 0.5, y: 1)
        }
    }

    func updateLocations() {
        gradientLayer.locations = [startLocation as NSNumber, endLocation as NSNumber]
    }

    func updateColors() {
        if NightNight.theme == .night{
            let startNightTheme = UIColor(red:0.14, green:0.14, blue:0.14, alpha:1.0)
            let endNightTheme = UIColor(red:0.12, green:0.11, blue:0.12, alpha:1.0)

            gradientLayer.colors    = [startNightTheme.cgColor, endNightTheme.cgColor]
        } else {
            gradientLayer.colors    = [startColor.cgColor, endColor.cgColor]
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
                guard let note = Storage.sharedInstance().getBy(url: url) else { continue }

                switch sidebarItem.type {
                case .Category, .Archive, .Inbox:
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

            note.url = dstURL
            note.parseURL()
            note.project = project

            // resets tags in sidebar
            removeTags(in: [note])

            // reload tags (in remove tags operation notn fitted)
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

        if let root = Storage.sharedInstance().getRootProject() {
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
        guard
            UserDefaultsManagement.inlineTags,
            let vc = viewController
        else { return }

        unloadAllTags()
        var tags = [String]()

        switch vc.searchQuery.type {
        case .Inbox, .All, .Todo:
            let notes = vc.notesTable.notes
            tags = getAllTags(notes: notes)
            break
        case .Category:
            guard let project = vc.searchQuery.project else { return }
            tags = getAllTags(projects: [project])
            break
        default:
            return
        }

        guard tags.count > 0 else { return }

        var indexPaths = [IndexPath]()
        for tag in tags {
            let position = self.sidebar.items[2].count
            let element = SidebarItem(name: tag, type: .Tag)
            self.sidebar.items[2].insert(element, at: position)
            indexPaths.append(IndexPath(row: position, section: 2))
        }

        insertRows(at: indexPaths, with: .automatic)
    }

    public func unloadAllTags() {
        guard sidebar.items[2].count > 0 else { return }

        let rows = numberOfRows(inSection: 2)

        if rows > 0 {
            self.sidebar.items[2].removeAll()

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
            guard let vc = viewController,
                let query = createQueryWithoutTags(),
                vc.isFit(note: note, searchQuery: query)
            else { continue }

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
        let currentTags = sidebar.items[2].compactMap({ $0.name })
        var toInsert = [String]()

        for tag in tags {
            if currentTags.contains(tag) {
                continue
            }
            toInsert.append(tag)
        }

        guard toInsert.count > 0 else { return }

        let nonSorted = currentTags + toInsert
        let sorted = nonSorted.sorted()

        var indexPaths = [IndexPath]()
        for tag in toInsert {
            guard let index = sorted.firstIndex(of: tag) else { continue }
            indexPaths.append(IndexPath(row: index, section: 2))
        }

        sidebar.items[2] = sorted.compactMap({ SidebarItem(name: $0, type: .Tag) })
        insertRows(at: indexPaths, with: .fade)
    }

    public func delete(tags: [String]) {
        guard let vc = viewController else { return }

        var allTags = [String]()

        if let project = vc.searchQuery.project {
            allTags = project.getAllTags()
        } else if let type = vc.searchQuery.type {
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

        let currentTags = sidebar.items[2].compactMap({ $0.name })
        var toRemovePaths = [IndexPath]()
        var toRemoveTags = [String]()

        for tag in tags {
            if !allTags.contains(tag) {
                if let row = currentTags.firstIndex(of: tag) {
                    toRemovePaths.append(IndexPath(row: row, section: 2))
                    toRemoveTags.append(tag)
                }
            }
        }

        sidebar.items[2].removeAll(where: { toRemoveTags.contains($0.name) })
        deleteRows(at: toRemovePaths, with: .fade)

        deSelectTagIfNonExist(tags: toRemoveTags)
    }

    private func createQueryWithoutTags() -> SearchQuery? {
        guard let vc = viewController else { return nil }
        let query = SearchQuery()

        query.project = vc.searchQuery.project
        if let type = vc.searchQuery.type {
            query.type = type

            if query.project != nil && type == .Tag {
                query.type = .Category
            }
        }

        return query
    }

    private func deSelectTagIfNonExist(tags: [String]) {
        guard let vc = viewController,
            let tag = vc.searchQuery.tag
        else { return }

        guard tags.contains(tag) else { return }

        if let project = vc.searchQuery.project,
            let index = getIndexPathBy(project: project)
        {
            tableView(self, didSelectRowAt: index)
            return
        }

        if let type = vc.searchQuery.type,
            let index = getIndexPathBy(type: type) {
            tableView(self, didSelectRowAt: index)
        }
    }

    public func getSelectedSidebarItem() -> SidebarItem? {
        guard let vc = viewController, let project = vc.searchQuery.project else { return nil }
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
        let currentProjects = sidebar.items[1].compactMap({ $0.project })
        var toInsert = [Project]()

        for project in projects {
            if currentProjects.contains(project) {
                continue
            }

            if !project.showInSidebar {
                continue
            }
            
            toInsert.append(project)
        }

        guard toInsert.count > 0 else { return }

        let nonSorted = currentProjects + toInsert
        let sorted = nonSorted.sorted { $0.label < $1.label }

        var indexPaths = [IndexPath]()
        for project in toInsert {
            guard let index = sorted.firstIndex(of: project) else { continue }
            indexPaths.append(IndexPath(row: index, section: 1))
        }

        sidebar.items[1] = sorted.compactMap({ SidebarItem(name: $0.label, project: $0, type: .Category) })
        insertRows(at: indexPaths, with: .fade)
    }
    
    public func removeRows(projects: [Project]) {
        guard projects.count > 0, let vc = viewController else { return }
        var deselectCurrent = false

        var indexPaths = [IndexPath]()
        for project in projects {
            if let index = sidebar.items[1].firstIndex(where: { $0.project == project }) {
                indexPaths.append(IndexPath(row: index, section: 1))

                if project == vc.searchQuery.project {
                    deselectCurrent = true
                }

                vc.storage.remove(project: project)
                sidebar.items[1].remove(at: index)
            }
        }

        deleteRows(at: indexPaths, with: .automatic)

        if deselectCurrent {
            vc.notesTable.notes.removeAll()
            vc.notesTable.reloadData()

            let indexPath = IndexPath(row: 0, section: 0)
            tableView(self, didSelectRowAt: indexPath)
        }
    }

    public func select(project: Project) {
        guard let indexPath = getIndexPathBy(project: project) else { return }
        tableView(self, didSelectRowAt: indexPath)
    }

    public func select(tag: String) {
        guard let indexPath = getIndexPathBy(tag: tag) else { return }
        tableView(self, didSelectRowAt: indexPath)

        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else {
            return
        }
        bvc.containerController.selectController(atIndex: 0, animated: true)
    }

    public func restoreSelection(for search: SearchQuery) {
        if let type = search.type {
            let index = getIndexPathBy(type: type)
            selectRow(at: index, animated: false, scrollPosition: .none)
        }

        if let project = search.project {
            let index = getIndexPathBy(project: project)
            selectRow(at: index, animated: false, scrollPosition: .none)
        }

        if let tag = search.tag {
            let index = getIndexPathBy(tag: tag)
            selectRow(at: index, animated: false, scrollPosition: .none)
        }
    }

    public func remove(tag: String) {
        guard let indexPath = getIndexPathBy(tag: tag) else { return }

        sidebar.items[2].removeAll(where: { $0.name == tag})
        deleteRows(at: [indexPath], with: .automatic)

        selectCurrentProject()
    }
}
