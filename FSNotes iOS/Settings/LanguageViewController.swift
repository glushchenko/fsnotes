//
//  LanguageViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 3/12/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class LanguageViewController: UITableViewController {
    private var languages: [String]? = []
    
    override func viewDidLoad() {
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: MixedColor(normal: 0x000000, night: 0xfafafa)]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.plain, target: self, action: #selector(LanguageViewController.cancel))
        
        for im in UITextInputMode.activeInputModes {
            if let lang = im.primaryLanguage {
                self.languages?.append(lang)
            }
        }
        
        self.title = "Default Keyboard"
        super.viewDidLoad()
    }
    
    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserDefaultsManagement.defaultLanguage = indexPath.row
        self.dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = languages?[indexPath.row]
        
        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let l = languages {
            return l.count
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
        
        let language = UserDefaultsManagement.defaultLanguage
        
        if indexPath.row == language {
            cell.accessoryType = .checkmark
        }
    }

}
