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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var lvc: UIViewController?
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        
        switch indexPath.row {
        case 0:
            lvc = DefaultExtensionViewController()
            lvc = storyBoard.instantiateViewController(withIdentifier: "defaultExtensionViewController") as! DefaultExtensionViewController
        case 1:
            lvc = LanguageViewController()
            lvc = storyBoard.instantiateViewController(withIdentifier: "languageViewController") as! LanguageViewController
        default:
            return
        }
        
        if let controller = lvc {
            let navigationController = UINavigationController(rootViewController: controller)
            
            self.present(navigationController, animated: true, completion: nil)
        }
    }
    
    @objc func done() {
        self.dismiss(animated: true, completion: nil)
    }
}

