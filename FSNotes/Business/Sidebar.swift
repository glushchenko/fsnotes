//
//  Sidebar.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

#if os(OSX)
    import Cocoa
    typealias Image = NSImage
#else
    import UIKit
    import NightNight
    typealias Image = UIImage
#endif

class Sidebar {
    var list = [SidebarItem]()
    let storage = Storage.sharedInstance()
    public var items = [[SidebarItem]]()
    
    init() {
        var night = ""
        var inboxName = "sidebarInbox"

#if os(iOS)
        night = "_white"
        inboxName = "inbox\(night).png"
#endif

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

        #if os(iOS)
            items.append(system)
        #else
            list = system
        #endif

        let rootProjects = storage.getRootProjects()

        for project in rootProjects {
            let icon = getImage(named: "repository\(night).png")
            
            #if os(OSX)
                let type: SidebarItemType = .Label
            #else
                let type: SidebarItemType = .Category
            #endif
            
            list.append(SidebarItem(name: project.label, project: project, type: type, icon: icon))
            
            let childProjects = storage.getChildProjects(project: project)
            for childProject in childProjects {
                if childProject.url == UserDefaultsManagement.archiveDirectory {
                    continue
                }
                
                list.append(SidebarItem(name: childProject.label, project: childProject, type: .Category, icon: icon))
            }
        }

        #if os(iOS)
            let projects = getProjects()
            if projects.count > 0 {
                items.append(projects)
            }
        #endif

        let rootTag = Tag(name: "# Tags")
        for tag in Storage.sharedInstance().getTagsV2() {
            rootTag.addChild(name: tag)
        }
        let tags = rootTag.getChild()

        if tags.count > 0 {
            var icon: Image? = nil

            #if os(iOS)
                var tagsSidebarItems = [SidebarItem]()

                for tag in tags {
                    tagsSidebarItems.append(SidebarItem(name: tag, type: .Tag, icon: icon))
                }

                if tagsSidebarItems.count > 0 {
                    items.append(tagsSidebarItems)
                }
            #else
                icon = getImage(named: "tag\(night).png")
                let tagsLabel = NSLocalizedString("Tags", comment: "Sidebar label")
                list.append(SidebarItem(name: "# \(tagsLabel)", type: .Label, icon: icon))

                for tag in tags {
                    list.append(SidebarItem(name: tag.getName(), type: .Tag, icon: icon, tag: tag))
                }
            #endif
        }

        #if os(iOS)
            let icon = getImage(named: "settings\(night).png")
            items.append([SidebarItem(name: "Settings", type: .Label, icon: icon)])
        #endif
    }
    
    public func getList() -> [SidebarItem] {
        return list
    }
    
    public func getTags() -> [SidebarItem] {
        return list.filter({ $0.type == .Tag })
    }
    
    public func getProjects() -> [SidebarItem] {
        return list.filter({ $0.type == .Category && $0.type != .Archive && $0.project != nil && $0.project!.showInSidebar })
    }
    
    public func getByIndexPath(path: IndexPath) -> SidebarItem? {
        #if os(OSX)
            let i = path.item
        #else
            let i = path.row
        #endif
        
        switch path.section {
        case 0:
            return list[i]
        case 1:
            return getProjects()[i]
        case 2:
            return getTags()[i]
        case 3:
            return list.last
        default:
            return nil
        }
    }
    
    private func getImage(named: String) -> Image? {
        #if os(OSX)
            if let image = NSImage(named: named) {
                return image
            }
        #else
            if let image = UIImage(named: named) {
                return image
            }
        #endif
        
        return nil
    }
}
