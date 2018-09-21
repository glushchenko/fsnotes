//
//  SettingsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class SettingsViewController: UITableViewController {
    
    var sections = ["General", "Editor", "UI", "View"]
    var rowsInSection = [2, 2, 2, 1]
        
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x2e2c32)
        
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header

        super.viewDidLoad()
        
        self.title = "Settings"

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(done))
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowsInSection[section]
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        
        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view
        
        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Default Extension"
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.textLabel?.text = "Default Keyboard In Editor"
                cell.accessoryType = .disclosureIndicator
            default:
                return cell
            }
        }
        
        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Code block live highlighting"
                cell.accessoryType = UserDefaultsManagement.codeBlockHighlight ? .checkmark : .none
            case 1:
                cell.textLabel?.text = "Live images preview"
                cell.accessoryType = UserDefaultsManagement.liveImagesPreview ? .checkmark : .none
            default:
                return cell
            }
        }
        
        if indexPath.section == 0x02 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Font"
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.textLabel?.text = "Night Mode"
                cell.accessoryType = .disclosureIndicator
            default:
                return cell
            }
        }

        if indexPath.section == 0x03 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Projects"
                cell.accessoryType = .disclosureIndicator
            default:
                return cell
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var lvc: UIViewController?
        
        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                lvc = DefaultExtensionViewController()
            case 1:
                lvc = LanguageViewController()
            default:
                return
            }
        }
        
        if indexPath.section == 0x01 {
            if let cell = tableView.cellForRow(at: indexPath) {
                if cell.accessoryType == .none {
                    cell.accessoryType = .checkmark
                    
                } else {
                    cell.accessoryType = .none
                }
                
                if indexPath.row == 1 {
                    UserDefaultsManagement.liveImagesPreview = (cell.accessoryType == .checkmark)
                } else {
                    UserDefaultsManagement.codeBlockHighlight = (cell.accessoryType == .checkmark)
                }
            }
        }
        
        if indexPath.section == 0x02 {
            switch indexPath.row {
            case 0:
                lvc = FontViewController()
            case 1:
                lvc = NightModeViewController(style: .grouped)
            default: break
                
            }
        }

        if indexPath.section == 0x03 {
            switch indexPath.row {
            case 0:
                lvc = ProjectsViewController()
            default: break

            }
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

