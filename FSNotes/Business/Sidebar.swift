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
    typealias Image = UIImage
#endif

class Sidebar {
    var list = [SidebarItem]()
    let storage = Storage.sharedInstance()
    
    init() {
        
        list = [
            SidebarItem(name: "Notes", type: .All, icon: Image(named: "home.png")),
            SidebarItem(name: "Trash", type: .Trash, icon: Image(named: "trash.png")),
        ]
        
        let rootProjects = storage.getRootProjects()
        for project in rootProjects {
            let icon = Image(named: "repository.png")
            
            #if os(OSX)
                let type: SidebarItemType = .Label
            #else
                let type: SidebarItemType = .Category
            #endif
            
            list.append(SidebarItem(name: project.label, project: project, type: type, icon: icon))
            
            let childProjects = storage.getChildProjects(project: project)
            for childProject in childProjects {
                list.append(SidebarItem(name: childProject.label, project: childProject, type: .Category, icon: icon))
            }
        }
        
        let tags = storage.getTags()
        if tags.count > 0 {
            let icon = Image(named: "tag.png")
            
            #if os(OSX)
                list.append(SidebarItem(name: "# Tags", type: .Label, icon: icon))
            #endif
            
            for tag in tags {
                list.append(SidebarItem(name: tag, type: .Tag, icon: icon))
            }
        }
    }
    
    public func getList() -> [SidebarItem] {
        return list
    }
    
    public func getTags() -> [SidebarItem] {
        return list.filter({ $0.type == .Tag })
    }
    
    public func getProjects() -> [SidebarItem] {
        return list.filter({ $0.type == .Category  })
    }
    
    public func getByIndexPath(path: IndexPath) -> SidebarItem? {
        switch path.section {
        case 0:
            return list[path.row]
        case 1:
            return getProjects()[path.row]
        case 2:
            return getTags()[path.row]
        default:
            return nil
        }
    }
}
