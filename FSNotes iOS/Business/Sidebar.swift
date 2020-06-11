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
        system.append(
            SidebarItem(
                name: NSLocalizedString("Notes", comment: ""),
                type: .All,
                icon: getImage(named: "home_white")
            )
        )

        // Todo
        system.append(
            SidebarItem(
                name: NSLocalizedString("Todo", comment: ""),
                type: .Todo,
                icon: getImage(named: "todo_sidebar_white")
            )
        )

        // Archive
        if let archiveProject = storage.getArchive() {
            system.append(
                SidebarItem(
                    name: NSLocalizedString("Archive", comment: ""),
                    project: archiveProject,
                    type: .Archive,
                    icon: getImage(named: "archive_white")
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
        items.append([])

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

    public func updateProjects() {
        let sidebarItems =
            storage.getAvailableProjects()
                .sorted(by: { $0.label < $1.label })
                .compactMap({
                    SidebarItem(
                        name: $0.label,
                        project: $0,
                        type: .Category,
                        icon: nil,
                        tag: nil)
                })

        items[1] = sidebarItems
    }

    private func getImage(named: String) -> Image? {
        if let image = UIImage(named: named) {
            return image
        }
        
        return nil
    }
}
