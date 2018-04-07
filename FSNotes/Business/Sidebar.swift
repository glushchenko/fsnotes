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
    
    init() {
        list = [
            SidebarItem(name: "Library", type: .Label),
            
            SidebarItem(name: "Home", type: .All),
            SidebarItem(name: "Trash", type: .Trash),
            
            SidebarItem(name: "Projects", type: .Label)
        ]
        
        let storageItemList = CoreDataManager.instance.fetchStorageList()
        for storageItem in storageItemList {
            guard let label = storageItem.label else {
                continue
            }
            
            guard let url = storageItem.getUrl() else {
                return
            }
            
            let project = Project(url: url)
            let sidebarItem = SidebarItem(name: label, project: project, type: .Category)
            list.append(sidebarItem)
        }
    }
    
    func getList() -> [SidebarItem] {
        return list
    }
}
