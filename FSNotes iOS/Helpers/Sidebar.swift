//
//  Sideabr.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 02.11.2019.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
typealias Image = UIImage

enum SidebarSection: Int {
    case System   = 0x00
    case Projects = 0x01
    case Tags     = 0x02
    case Settings = 0x03
}

class Sidebar {
    let storage = Storage.shared()
    public var items = [[SidebarItem]]()
    public var allItems = [[SidebarItem]]()

    init() {
        guard let defaultURL = Storage.shared().getDefault()?.url else { return }
        storage.restoreProjectsExpandState()

        var system = [SidebarItem]()

        // Notes
        let notesUrl = defaultURL.appendingPathComponent("Fake Virtual Notes Dir")
        let notesLabel = NSLocalizedString("Notes", comment: "Sidebar items")
        
        if UserDefaultsManagement.sidebarVisibilityNotes {
            let fakeNotesProject =
                Project(
                    storage: Storage.shared(),
                    url: notesUrl,
                    label: notesLabel,
                    isVirtual: true
                )
            
            Storage.shared().allNotesProject = fakeNotesProject
            
            system.append(
                SidebarItem(
                    name: NSLocalizedString("Notes", comment: ""),
                    project: fakeNotesProject,
                    type: .All
                )
            )
        }

        // Inbox
        if UserDefaultsManagement.sidebarVisibilityInbox,
            let project = Storage.shared().getDefault() {
            system.append(
                SidebarItem(
                    name: NSLocalizedString("Inbox", comment: ""),
                    project: project,
                    type: .Inbox
                )
            )
        }

        // Todo
        if UserDefaultsManagement.sidebarVisibilityTodo {
            let todoUrl = defaultURL.appendingPathComponent("Fake Virtual Todo Dir")
            let todoLabel = NSLocalizedString("Todo", comment: "Sidebar items")
            let fakeTodoProject =
                Project(
                    storage: Storage.shared(),
                    url: todoUrl,
                    label: todoLabel,
                    isVirtual: true
                )

            system.append(
                SidebarItem(
                    name: NSLocalizedString("Todo", comment: ""),
                    project: fakeTodoProject,
                    type: .Todo
                )
            )

            Storage.shared().todoProject = fakeTodoProject
        }

        // Untagged
        if UserDefaultsManagement.sidebarVisibilityUntagged {
            let todoUrl = defaultURL.appendingPathComponent("Fake Virtual Utagged Dir")
            let untaggedLabel = NSLocalizedString("Untagged", comment: "")
            let fakeUntaggedProject =
                Project(
                    storage: Storage.shared(),
                    url: todoUrl,
                    label: untaggedLabel,
                    isVirtual: true
                )

            let untagged =
                SidebarItem(
                    name: untaggedLabel,
                    project: fakeUntaggedProject,
                    type: .Untagged
                )

            system.append(untagged)
        }

        // Trash
        if UserDefaultsManagement.sidebarVisibilityTrash {
            system.append(
                SidebarItem(
                    name: NSLocalizedString("Trash", comment: ""),
                    project: Storage.shared().getDefaultTrash(),
                    type: .Trash
                )
            )
        }

        // System - section 0
        items.append(system)

        // Projects - section 1
        items.append(makeProjectItems())

        // Tags - section 2
        items.append([])
    }

    /// Returns the visible projects in outline order: a folder is followed by
    /// its children, matching the hierarchy used by the macOS sidebar.
    private func makeProjectItems() -> [SidebarItem] {
        let projects = storage.getAvailableProjects()
        var visited = Set<ObjectIdentifier>()
        var result = [Project]()

        func sorted(_ projects: [Project]) -> [Project] {
            projects.sorted {
                $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
        }

        func append(_ project: Project) {
            let identifier = ObjectIdentifier(project)
            guard !visited.contains(identifier) else { return }

            visited.insert(identifier)
            result.append(project)

            if project.isExpanded {
                let children = projects.filter { $0.parent === project }
                sorted(children).forEach(append)
            }
        }

        let roots = projects.filter { project in
            guard let parent = project.parent else { return true }
            return parent.isDefault || !projects.contains(where: { $0 === parent })
        }

        sorted(roots).forEach(append)

        return result.map {
            SidebarItem(name: $0.label, project: $0, type: .Project)
        }
    }

    public func reloadProjects() {
        guard items.indices.contains(SidebarSection.Projects.rawValue) else { return }
        items[SidebarSection.Projects.rawValue] = makeProjectItems()
    }
}
