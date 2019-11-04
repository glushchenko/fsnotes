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

class Sidebar {
    var list = [Any]()
    let storage = Storage.sharedInstance()
    public var items = [[SidebarItem]]()

    init() {
        var night = ""
        var inboxName = "sidebarInbox"

        night = "_white"
        inboxName = "inbox\(night).png"

        var system = [SidebarItem]()

        if let project = Storage.sharedInstance().getDefault() {
            let inbox = SidebarItem(name: NSLocalizedString("Inbox", comment: ""), project: project, type: .Inbox, icon: getImage(named: inboxName))
            system.append(inbox)
        }

        let notes = SidebarItem(name: NSLocalizedString("Notes", comment: ""), type: .All, icon: getImage(named: "home\(night).png"))
        system.append(notes)

        let todo = SidebarItem(name: NSLocalizedString("Todo", comment: ""), type: .Todo, icon: getImage(named: "todo_sidebar\(night)"))
        system.append(todo)

        if let archiveProject = storage.getArchive() {
            let archive = SidebarItem(name: NSLocalizedString("Archive", comment: ""), project: archiveProject, type: .Archive, icon: getImage(named: "archive\(night).png"))
            system.append(archive)
        }

        let trashProject = Storage.sharedInstance().getDefaultTrash()
        let trash = SidebarItem(name: NSLocalizedString("Trash", comment: ""), project: trashProject, type: .Trash, icon: getImage(named: "trash\(night)"))

        system.append(trash)
        items.append(system)

        let rootProjects = storage.getRootProjects()

        for project in rootProjects {
            let icon = getImage(named: "repository\(night).png")
            let type: SidebarItemType = .Category

            list.append(SidebarItem(name: project.label, project: project, type: type, icon: icon))

            let childProjects = storage.getChildProjects(project: project)
            for childProject in childProjects {
                if childProject.url == UserDefaultsManagement.archiveDirectory {
                    continue
                }

                list.append(SidebarItem(name: childProject.label, project: childProject, type: .Category, icon: icon))
            }
        }

        let projects = getProjects()
        if projects.count > 0 {
            items.append(projects)
        }

        if UserDefaultsManagement.inlineTags {
            items.append([])
        } else {
            let tags = storage.getTags()
            if tags.count > 0 {
                var tagsSidebarItems = [SidebarItem]()
                for tag in tags {
                    tagsSidebarItems.append(SidebarItem(name: tag, type: .Tag, icon: nil))
                }
                
                if tagsSidebarItems.count > 0 {
                    items.append(tagsSidebarItems)
                }
            }
        }

        let icon = getImage(named: "settings\(night).png")
        items.append([SidebarItem(name: "Settings", type: .Label, icon: icon)])
    }

    public func getList() -> [Any] {
        return list
    }

    public func getTags() -> [Tag] {
        return list.filter({ ($0 as? Tag) != nil }) as! [Tag]
    }

    public func getProjects() -> [SidebarItem] {
        return list.filter({ ($0 as? SidebarItem)?.type == .Category && ($0 as? SidebarItem)?.type != .Archive && ($0 as? SidebarItem)?.project != nil && ($0 as? SidebarItem)!.project!.showInSidebar }) as! [SidebarItem]
    }

    private func getImage(named: String) -> Image? {
        if let image = UIImage(named: named) {
            return image
        }
        
        return nil
    }

    public func add(tag: Tag, section: Int) {
        let si = SidebarItem(name: tag.getName(), type: .Tag)
        items[section].append(si)
    }
}
