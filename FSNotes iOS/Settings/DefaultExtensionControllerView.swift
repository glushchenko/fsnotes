//
//  DefaultExtensionControllerView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/28/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class DefaultExtensionViewController: UITableViewController {
    private var extensions = ["md", "txt", "rtf", "markdown", "fountain"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(DefaultExtensionViewController.cancel))
        self.title = "Default Extension"
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
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if cell.textLabel?.text == UserDefaultsManagement.storageExtension {
            cell.accessoryType = .checkmark
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return extensions.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = extensions[indexPath.row]
        
        return cell
    }
}
