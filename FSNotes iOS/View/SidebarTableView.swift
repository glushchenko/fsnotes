//
//  SidebarTableView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 5/5/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

import UIKit
import NightNight

class SidebarTableView: UITableView,
    UITableViewDelegate,
    UITableViewDataSource  {
    
    var sidebar: Sidebar?
    private var sections = ["FSNotes", "Folders", "Tags"]

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.hasTags() ? 3 : 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sidebar = sidebar else { return 1 }
        
        switch section {
        case 0:
            return 2
        case 1:
            return sidebar.getProjects().count
        case 2:
            return sidebar.getTags().count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "sidebarCell", for: indexPath) as! SidebarTableCellView
        
        guard let sidebar = sidebar else { return cell }
        if let sidebarItem = sidebar.getByIndexPath(path: indexPath) {
            cell.configure(sidebarItem: sidebarItem)
        }
        
        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xccdbcd, night: 0x686372)
        cell.selectedBackgroundView = view
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        }
        
        return 45
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.backgroundView?.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x596263)
            
            var font: UIFont = UIFont.systemFont(ofSize: 15)
            
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .caption1)
                font = fontMetrics.scaledFont(for: font)
            }
            
            view.textLabel?.font = font.bold()
            view.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 45
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = getListController()
        vc.updateTable() {}
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xf7f5f3, night: 0x313636)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
    
    func getListController() -> ViewController {
        let pageViewController = UIApplication.shared.windows[0].rootViewController as? PageViewController
        let viewController = pageViewController?.orderedViewControllers[0] as? ViewController
        
        return viewController!
    }
    
    private func hasTags() -> Bool {
        return Storage.sharedInstance().hasTags()
    }
    
}
