//
//  SettingsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(SettingsViewController.done))
        self.title = "Settings"
    }
    
    @objc func done() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
            let sourceSelectorTableViewController = storyBoard.instantiateViewController(withIdentifier: "defaultExtensionViewController") as! DefaultExtensionViewController
            let navigationController = UINavigationController(rootViewController: sourceSelectorTableViewController)
            
            self.present(navigationController, animated: true, completion: nil)
        }
    }
 
}

