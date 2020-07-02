//
//  Sideabr.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 02.11.2019.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight
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

        // Inbox
        if let project = Storage.shared().getDefault() {
            system.append(
                SidebarItem(
                    name: NSLocalizedString("Inbox", comment: ""),
                    project: project,
                    type: .Inbox,
                    icon: getImage(named: "inbox_white")
                )
            )
        }

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
                type: .All,
                icon: getImage(named: "sidebar_home")
            )
        )

        // Todo
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
                type: .Todo,
                icon: getImage(named: "sidebar_todo")
            )
        )

        // Archive
        if let archiveProject = storage.getArchive() {
            system.append(
                SidebarItem(
                    name: NSLocalizedString("Archive", comment: ""),
                    project: archiveProject,
                    type: .Archive,
                    icon: getImage(named: "sidebar_archive")
                )
            )
        }

        // Trash
        system.append(
            SidebarItem(
                name: NSLocalizedString("Trash", comment: ""),
                project: Storage.shared().getDefaultTrash(),
                type: .Trash,
                icon: getImage(named: "trash_white")
            )
        )

        // System - section 0
        items.append(system)

        // Projects - section 1
        let projects = storage
            .getAvailableProjects()
            .sorted(by: { $0.label < $1.label })
            .map({
                SidebarItem(name: $0.label, project: $0, type: .Category)
            })

        items.append(projects)

        // Tags - section 2
        items.append([])

        // Settings - section 3
        items.append(
            [SidebarItem(
                name: NSLocalizedString("Settings", comment: "Sidebar settings"),
                type: .Label,
                icon: getImage(named: "settings_white")
            )]
        )
    }

    private func getImage(named: String) -> Image? {
        if let image = UIImage(named: named) {
            return image.imageWithColor(color1: .white)
        }
        
        return nil
    }
}
