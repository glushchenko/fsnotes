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
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        
        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))
        
        for im in UITextInputMode.activeInputModes {
            if let lang = im.primaryLanguage {
                self.languages?.append(lang)
            }
        }
        
        self.title = NSLocalizedString("Default Keyboard In Editor", comment: "Settings")
        super.viewDidLoad()
    }
    
    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserDefaultsManagement.defaultLanguage = indexPath.row
        self.navigationController?.popViewController(animated: true)
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
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
        
        let language = UserDefaultsManagement.defaultLanguage
        
        if indexPath.row == language {
            cell.accessoryType = .checkmark
        }
    }

}
