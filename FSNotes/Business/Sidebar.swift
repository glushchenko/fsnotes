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


        if let defaultProject = storage.getDefault() {
            let name = getDefaultLabelName(project: defaultProject)
            let icon = NSImage(named: "sidebar_icloud_drive")
            list.append(SidebarItem(name: name, project: defaultProject, type: .Header, icon: icon))

            let subDefault = defaultProject.child.sorted(by: { $0.label.lowercased() < $1.label.lowercased() })
            for project in subDefault {
                list.append(project)
            }
        }

        let externalProjects = storage.getExternalProjects()
        if externalProjects.count > 0 {
            let icon = NSImage(named: "sidebar_external")
            let name = NSLocalizedString("External Folders", comment: "")
            list.append(SidebarItem(name: "", type: .Label))
            list.append(SidebarItem(name: name, type: .Header, icon: icon))

            for project in externalProjects {
                list.append(project)
            }
        }

        list.append(SidebarItem(name: "", type: .Label))
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
