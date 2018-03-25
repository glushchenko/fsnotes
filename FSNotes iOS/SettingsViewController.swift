//
//  SettingsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import Solar
import CoreLocation
import NightNight

class SettingsViewController: UITableViewController, CLLocationManagerDelegate {
    
    var sections = ["General", "Editor", "UI"]
    var rowsInSection = [2, 2, 3]
    let nightModeButton = UISwitch()
    let nightModeAutoButton = UISwitch()
    let locationManager = CLLocationManager()
        
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)
        
        nightModeAutoButton.addTarget(self, action: #selector(self.nightModeAutoDidChange), for: .valueChanged)
        
        nightModeButton.addTarget(self, action: #selector(self.nightModeDidChange), for: .valueChanged)
        
        initNightMode()
        
        nightModeButton.isOn = (NightNight.theme == .night)
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(SettingsViewController.done))
        self.title = "Settings"
        
        locationManager.delegate = self
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
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
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        
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
                cell.accessoryType = .none
                cell.accessoryView = nightModeButton
            case 2:
                cell.textLabel?.text = "Night Mode Auto"
                cell.accessoryType = .none
                cell.accessoryView = nightModeAutoButton
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
    
    @objc func nightModeDidChange(sender: UISwitch) {
        if sender.isOn {
            UIApplication.shared.statusBarStyle = .lightContent
            NightNight.theme = .night
        } else {
            UIApplication.shared.statusBarStyle = .default
            NightNight.theme = .normal
        }
    }
    
    @objc func nightModeAutoDidChange(sender: UISwitch) {
        if sender.isOn {
            UserDefaultsManagement.nightModeAuto = true
            locationManager.requestWhenInUseAuthorization()
        } else {
            UserDefaultsManagement.nightModeAuto = false
        }
    }
    
    func initNightMode() {
        if UserDefaultsManagement.nightModeAuto {
            var nightModeAuto = false
            
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
                break
            case .denied:
                break
            case .restricted:
                break
            case .authorizedWhenInUse:
                nightModeAuto = true
                break
            case .authorizedAlways:
                nightModeAuto = true
            }
            
            nightModeAutoButton.setOn(nightModeAuto, animated: true)
            UserDefaultsManagement.nightModeAuto = nightModeAuto
        } else {
            nightModeAutoButton.setOn(false, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if UserDefaultsManagement.nightModeAuto {
            nightModeAutoButton.isOn = (status == .authorizedWhenInUse)
        }
    }
}

