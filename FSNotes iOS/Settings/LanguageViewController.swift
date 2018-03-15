//
//  LanguageViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 3/12/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class LanguageViewController: UITableViewController {
    private var languages: [String]? = []
    
    override func viewDidLoad() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(LanguageViewController.cancel))
        
        for im in UITextInputMode.activeInputModes {
            if let lang = im.primaryLanguage {
                self.languages?.append(lang)
            }
        }
        
        self.title = "Default Keyboard"
        super.viewDidLoad()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        guard let language = UserDefaultsManagement.defaultLanguage else {
            return
        }
        
        let cells = self.tableView.visibleCells
        for cell in cells {
            if cell.textLabel?.text == language {
                cell.accessoryType = .checkmark
            }
        }
        
        super.viewDidAppear(animated)
    }
    
    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath), let label = cell.textLabel, let dl = label.text {
            UserDefaultsManagement.defaultLanguage = dl
            
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = languages?[indexPath.row]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let l = languages {
            return l.count
        }
        
        return 0
    }
}
