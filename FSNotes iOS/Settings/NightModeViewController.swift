//
//  NightModeViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 3/30/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class NightModeViewController: UITableViewController {
    var sections = [
        NSLocalizedString("Type", comment: ""),
        NSLocalizedString("Brightness level", comment: "")
    ]
    var rowsInSection = [3, 1, 1]
    
    var rows = [
        [
            NSLocalizedString("Disabled", comment: ""),
            NSLocalizedString("Enabled", comment: ""),
            NSLocalizedString("System", comment: ""),
            NSLocalizedString("Auto by screen brightness", comment: "")
        ],
        [""]
    ]
    
    let nightModeButton = UISwitch()
    let nightModeAutoButton = UISwitch()
    
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))
        self.title = NSLocalizedString("Night Mode", comment: "Settings")
        
        super.viewDidLoad()
    }
    
    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView(frame: .zero)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return UserDefaultsManagement.nightModeType == .brightness ? 2 : 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows[section].count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = rows[indexPath.section][indexPath.row]
        cell.selectionStyle = .none
        
        if indexPath.section == 0 {
            cell.textLabel?.text = rows[indexPath.section][indexPath.row]
            cell.accessoryType = (UserDefaultsManagement.nightModeType.rawValue == indexPath.row) ? .checkmark : .none
        }
        
        if indexPath.section == 1 {
            let brightness = UserDefaultsManagement.maxNightModeBrightnessLevel
            let slider = UISlider(frame: CGRect(x: 10, y: 3, width: tableView.frame.width - 20, height: 40))
            slider.minimumValue = 0
            slider.maximumValue = 1
            slider.addTarget(self, action: #selector(didChangeBrightnessSlider), for: .touchUpInside)
            slider.setValue(brightness, animated: true)
            cell.addSubview(slider)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {        
        if indexPath.section == 0 {
            guard let nightMode = NightMode(rawValue: indexPath.row) else {
                return
            }
            
            UserDefaultsManagement.nightModeType = nightMode
            
            for i in 0...3 {
                let cell = tableView.cellForRow(at: IndexPath(row: i, section: 0))
                cell?.accessoryType = .none
                
                if i == indexPath.row {
                    cell?.accessoryType = .checkmark
                }
            }
            
            if nightMode == .system {
                if #available(iOS 12.0, *) {
                    NightNight.theme = traitCollection.userInterfaceStyle == .dark ? .night : .normal
                }
            }
            
            if nightMode == .disabled {
                NightNight.theme = .normal
            }
            
            if nightMode == .enabled {
                NightNight.theme = .night
            }
            
            if nightMode == .brightness {
                NotificationCenter.default.post(name: UIScreen.brightnessDidChangeNotification, object: nil)
            }
            
            tableView.reloadData()
            
            guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
                let vc = pc.containerController.viewControllers[0] as? ViewController else { return }
            
            vc.notesTable.layoutSubviews()
            vc.sidebarTableView.layoutSubviews()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }

    @objc func didChangeBrightnessSlider(sender: UISlider) {
        UserDefaultsManagement.maxNightModeBrightnessLevel = sender.value
        NotificationCenter.default.post(name: UIScreen.brightnessDidChangeNotification, object: nil)
    }
}
