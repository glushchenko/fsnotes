//
//  FontViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 3/16/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class FontViewController: UITableViewController {
    private var fontFamilyNames = [
        "System",
        "Avenir Next",
        "Georgia",
        "Helvetica Neue",
        "Menlo",
        "Courier",
        "Palatino"
    ]
    
    override func viewDidLoad() {
        title = NSLocalizedString("Font Family", comment: "Settings")
        
        super.viewDidLoad()
    }
    
    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if UserDefaultsManagement.fontName == nil && indexPath.row == 0 {
            cell.accessoryType = .checkmark
        }

        if fontFamilyNames[indexPath.row] == UserDefaultsManagement.noteFont.familyName {
            cell.accessoryType = .checkmark
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath), let label = cell.textLabel, let fontFamily = label.text {
            let fontSize = UserDefaultsManagement.fontSize

            if indexPath.row == 0 {
                UserDefaultsManagement.fontName = nil
            } else if let customFont = UIFont(name: fontFamily, size: CGFloat(fontSize)) {
                UserDefaultsManagement.noteFont = customFont
            }

            MPreviewView.template = nil

            UIApplication.getVC().notesTable.reloadData()
            
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = fontFamilyNames[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fontFamilyNames.count
    }
}

