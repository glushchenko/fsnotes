//
//  DefaultExtensionControllerView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/28/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class DefaultExtensionViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(DefaultExtensionViewController.cancel))
        self.title = "Default Extension"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let cells = self.tableView.visibleCells
        for cell in cells {
            if cell.textLabel?.text == UserDefaultsManagement.storageExtension {
                cell.accessoryType = .checkmark
            }
        }
        
        super.viewDidAppear(animated)
    }
    
    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath), let label = cell.textLabel {
            UserDefaultsManagement.storageExtension = label.text!
            
            self.dismiss(animated: true, completion: nil)
        }
    }
}
