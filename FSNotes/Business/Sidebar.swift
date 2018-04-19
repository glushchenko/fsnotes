//
//  Sidebar.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class Sidebar {
    var list = [SidebarItem]()
    let storage = Storage.sharedInstance()
    
    init() {
        list = [
            SidebarItem(name: "FSNotes", type: .Label),
            SidebarItem(name: "Notes", type: .All),
            SidebarItem(name: "Trash", type: .Trash),
        ]
        
        let rootProjects = storage.getRootProjects()
        for project in rootProjects {
            list.append(SidebarItem(name: project.label, project: project, type: .Label))
            let childProjects = storage.getChildProjects(project: project)
            for childProject in childProjects {
                list.append(SidebarItem(name: childProject.label, project: childProject, type: .Category))
            }
        }
        
        let tags = storage.getTags()
        if tags.count > 0 {
            list.append(SidebarItem(name: "# Tags", type: .Label))
            
            for tag in tags {
                list.append(SidebarItem(name: tag, type: .Tag))
            }
        }
    }
    
    func getList() -> [SidebarItem] {
        return list
    }
}
