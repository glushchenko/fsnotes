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
    
    override func draw(_ rect: CGRect) {
        dataSource = self
        delegate = self
        
        backgroundColor = UIColor(red:0.89, green:0.89, blue:0.89, alpha:1.0)
        
        if let pageViewController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageViewController.orderedViewControllers[0] as? ViewController {
            vc.sidebarWidthConstraint.constant = UserDefaultsManagement.sidebarSize
        }
        
        super.draw(rect)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
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
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        }
        
        return 50
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.backgroundView?.backgroundColor = UIColor(red:0.73, green:0.73, blue:0.73, alpha:1.0)
            
            var font: UIFont = UIFont.systemFont(ofSize: 15)
            
            if #available(iOS 11.0, *) {
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font)
            }
            
            view.textLabel?.font = font.bold()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 45
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(indexPath.row)
        
        let vc = getListController()
        vc.updateList()
    }
    
    func getListController() -> ViewController {
        let pageViewController = UIApplication.shared.windows[0].rootViewController as? PageViewController
        let viewController = pageViewController?.orderedViewControllers[0] as? ViewController
        
        return viewController!
    }
    
}
