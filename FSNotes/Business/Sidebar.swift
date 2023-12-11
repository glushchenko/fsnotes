//
//  Sidebar.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
typealias Image = NSImage

class Sidebar {
    var list = [Any]()
    let storage = Storage.shared()
    public var items = [[SidebarItem]]()
    
    init() {
        var system = [SidebarItem]()

        if UserDefaultsManagement.sidebarVisibilityInbox {
            let notes = SidebarItem(name: NSLocalizedString("Inbox", comment: ""), type: .Inbox)
            system.append(notes)
        }

        if UserDefaultsManagement.sidebarVisibilityNotes {
            let notes = SidebarItem(name: NSLocalizedString("Notes", comment: ""), type: .All)
            system.append(notes)
        }

        if UserDefaultsManagement.sidebarVisibilityTodo {
            let todo = SidebarItem(name: NSLocalizedString("Todo", comment: ""), type: .Todo)
            system.append(todo)
        }

        if UserDefaultsManagement.sidebarVisibilityUntagged {
            let todo = SidebarItem(name: NSLocalizedString("Untagged", comment: ""), type: .Untagged)
            system.append(todo)
        }

        if UserDefaultsManagement.sidebarVisibilityTrash {
            let trashProject = Storage.shared().getDefaultTrash()
            let trash = SidebarItem(name: NSLocalizedString("Trash", comment: ""), project: trashProject, type: .Trash)
            system.append(trash)
        }

        if system.count > 0 {
            list = system
        }

        list.append(SidebarItem(name: "projects", type: .Separator))

        let projects = storage.getSidebarProjects()
        if projects.count > 0 {
            for project in projects {
                list.append(project)
            }
        }

        list.append(SidebarItem(name: "tags", type: .Separator))
    }
    
    public func getList() -> [Any] {
        return list
    }

    private func getDefaultLabelName(project: Project) -> String {
        var name = project.label

        let iCloudPath = "/Users/\(NSUserName())/Library/Mobile Documents"
        if project.url.path.starts(with: iCloudPath) {
            name = NSLocalizedString("iCloud Drive", comment: "")
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path
        if let path = documentsPath, project.url.path.starts(with: path) {
            name = NSLocalizedString("Documents", comment: "")
        }

        return name
    }
}
