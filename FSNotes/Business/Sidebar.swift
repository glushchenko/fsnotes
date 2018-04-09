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
            
        ]
        
        let localProjects = storage.getLocalProjects()
        if localProjects.count > 0 {
            list.append(SidebarItem(name: "Local", type: .Label))
            for project in localProjects {
                guard let label = project.label else {
                    continue
                }
                
                let sidebarItem = SidebarItem(name: label, project: project, type: .Category)
                list.append(sidebarItem)
            }
        }
        
        let cloudDriveProjects = storage.getCloudDriveProjects()
        if cloudDriveProjects.count > 0 {
            list.append(SidebarItem(name: "iCloud Drive", type: .Label))
            for project in cloudDriveProjects {
                guard let label = project.label else {
                    continue
                }
                
                let sidebarItem = SidebarItem(name: label, project: project, type: .Category)
                list.append(sidebarItem)
            }
        }
    }
    
    func getList() -> [SidebarItem] {
        return list
    }
}
