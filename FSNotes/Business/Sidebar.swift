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
            SidebarItem(name: "Library", type: .Label),
            
            SidebarItem(name: "Home", type: .All),
            SidebarItem(name: "Trash", type: .Trash),
            
            SidebarItem(name: "Projects", type: .Label)
        ]
        
        let projects = storage.getProjects()
        for project in projects {
            guard let label = project.label else {
                continue
            }
            
            let sidebarItem = SidebarItem(name: label, project: project, type: .Category)
            list.append(sidebarItem)
        }
    }
    
    func getList() -> [SidebarItem] {
        return list
    }
}
