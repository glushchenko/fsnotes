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
        let night = ""
        let inboxName = "sidebarInbox"
        var system = [SidebarItem]()

        if UserDefaultsManagement.sidebarVisibilityInbox, let project = Storage.sharedInstance().getDefault() {
            let inbox = SidebarItem(name: NSLocalizedString("Inbox", comment: ""), project: project, type: .Inbox, icon: getImage(named: inboxName))
            system.append(inbox)
        }

        if UserDefaultsManagement.sidebarVisibilityNotes {
            let notes = SidebarItem(name: NSLocalizedString("Notes", comment: ""), type: .All, icon: getImage(named: "home\(night).png"))
            system.append(notes)
        }

        if UserDefaultsManagement.sidebarVisibilityTodo {
            let todo = SidebarItem(name: NSLocalizedString("Todo", comment: ""), type: .Todo, icon: getImage(named: "todo_sidebar\(night)"))
            system.append(todo)
        }

        if UserDefaultsManagement.sidebarVisibilityArchive, let archiveProject = storage.getArchive() {
            let archive = SidebarItem(name: NSLocalizedString("Archive", comment: ""), project: archiveProject, type: .Archive, icon: getImage(named: "archive\(night).png"))
            system.append(archive)
        }

        if UserDefaultsManagement.sidebarVisibilityTrash {
            let trashProject = Storage.sharedInstance().getDefaultTrash()
            let trash = SidebarItem(name: NSLocalizedString("Trash", comment: ""), project: trashProject, type: .Trash, icon: getImage(named: "trashBin"))
            system.append(trash)
        }

        if system.count > 0 {
            list = system
        }

        let projectsLabel = NSLocalizedString("Projects", comment: "Sidebar label")
        list.append(SidebarItem(name: "\(projectsLabel)", type: .Label))

        let rootProjects = storage.getRootProjects()
        for project in rootProjects {
            list.append(project)
        }

        let tagsLabel = NSLocalizedString("Tags", comment: "Sidebar label")
        list.append(SidebarItem(name: tagsLabel, type: .Label))
    }
    
    public func getList() -> [Any] {
        return list
    }

    private func getImage(named: String) -> Image? {
        if let image = NSImage(named: named) {
            return image
        }
        
        return nil
    }
}
