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
    
    init() {
        var night = ""
        #if os(iOS)
        if NightNight.theme == .night {
                night = "_white"
        }
        #endif
        
        list.append(
            SidebarItem(name: NSLocalizedString("Notes", comment: ""), type: .All, icon: getImage(named: "home\(night).png"))
        )
        
        if let archiveProject = storage.getArchive() {
            list.append(
                SidebarItem(name: NSLocalizedString("Archive", comment: ""), project: archiveProject, type: .Archive, icon: getImage(named: "archive\(night).png"))
            )
        }
        
        list.append(
            SidebarItem(name: NSLocalizedString("Trash", comment: ""), type: .Trash, icon: getImage(named: "trash\(night).png"))
        )
        
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
        
        let tags = storage.getTags()
        if tags.count > 0 {
            let icon = getImage(named: "tag\(night).png")
            
            #if os(OSX)
                let tagsLabel = NSLocalizedString("Tags", comment: "Sidebar label")
                list.append(SidebarItem(name: "# \(tagsLabel)", type: .Label, icon: icon))
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
        return list.filter({ $0.type == .Category && $0.type != .Archive })
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
        default:
            return nil
        }
    }
    
    private func getImage(named: String) -> Image? {
        #if os(OSX)
            if let image = NSImage(named: NSImage.Name.init(rawValue: named)) {
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
