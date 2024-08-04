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

        var system = [SidebarItem]()

        // Notes
        let notesUrl = defaultURL.appendingPathComponent("Fake Virtual Notes Dir")
        let notesLabel = NSLocalizedString("Notes", comment: "Sidebar items")
        let fakeNotesProject =
            Project(
                storage: Storage.shared(),
                url: notesUrl,
                label: notesLabel,
                isVirtual: true
            )

        system.append(
            SidebarItem(
                name: NSLocalizedString("Notes", comment: ""),
                project: fakeNotesProject,
                type: .All
            )
        )

        Storage.shared().allNotesProject = fakeNotesProject

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
        let projects = storage
            .getAvailableProjects()
            .sorted(by: { $0.label < $1.label })
            .map({
                SidebarItem(
                    name: $0.label,
                    project: $0,
                    type: .Project
                )
            })

        items.append(projects)

        // Tags - section 2
        items.append([])
    }
}
