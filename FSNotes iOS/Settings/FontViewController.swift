//
//  FontViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 3/16/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class FontViewController: UITableViewController {
    private var fontFamilyNames = [
        "System",
        "Avenir Next",
        "Georgia",
        "Helvetica Neue",
        "Menlo"
    ]
    
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        
        navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))
        
        title = NSLocalizedString("Font Family", comment: "Settings")
        
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        
        super.viewDidLoad()
    }
    
    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

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
                UserDefaultsManagement.noteFont = nil
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
        
        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fontFamilyNames.count
    }
}

