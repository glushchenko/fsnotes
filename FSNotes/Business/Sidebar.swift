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
    let storage = Storage.sharedInstance()
    public var items = [[SidebarItem]]()
    
    init() {
        var system = [SidebarItem]()

        if UserDefaultsManagement.sidebarVisibilityInbox, let project = Storage.sharedInstance().getDefault() {
            let inbox = SidebarItem(name: NSLocalizedString("Inbox", comment: ""), project: project, type: .Inbox)
            system.append(inbox)
        }

        if UserDefaultsManagement.sidebarVisibilityNotes {
            let notes = SidebarItem(name: NSLocalizedString("Notes", comment: ""), type: .All)
            system.append(notes)
        }

        if UserDefaultsManagement.sidebarVisibilityTodo {
            let todo = SidebarItem(name: NSLocalizedString("Todo", comment: ""), type: .Todo)
            system.append(todo)
        }

        if UserDefaultsManagement.sidebarVisibilityArchive, let archiveProject = storage.getArchive() {
            let archive = SidebarItem(name: NSLocalizedString("Archive", comment: ""), project: archiveProject, type: .Archive)
            system.append(archive)
        }

        if UserDefaultsManagement.sidebarVisibilityTrash {
            let trashProject = Storage.sharedInstance().getDefaultTrash()
            let trash = SidebarItem(name: NSLocalizedString("Trash", comment: ""), project: trashProject, type: .Trash)
            system.append(trash)
        }

        if system.count > 0 {
            list = system
        }

        list.append(SidebarItem(name: "", type: .Label))

        let rootProjects = storage.getRootProjects()
        for project in rootProjects {
            list.append(project)
        }

        list.append(SidebarItem(name: "", type: .Label))
    }
    
    public func getList() -> [Any] {
        return list
    }
}
