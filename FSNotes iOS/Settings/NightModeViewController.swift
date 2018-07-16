//
//  NightModeViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 3/30/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import Solar
import NightNight
import CoreLocation

class NightModeViewController: UITableViewController, CLLocationManagerDelegate {
    var sections = ["Type", "Brightness level"]
    var rowsInSection = [3, 1, 1]
    
    var rows = [
        ["Disabled", "Enabled", "Auto by location", "Auto by screen brightness"],
        [""]
    ]
    
    let nightModeButton = UISwitch()
    let nightModeAutoButton = UISwitch()
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: MixedColor(normal: 0x000000, night: 0xfafafa)]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(cancel))
        self.title = "Night Mode"
        
        initNightMode()
        super.viewDidLoad()
        
        locationManager.delegate = self
    }
    
    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
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
            
            if nightMode == .location {
                UserDefaultsManagement.nightModeAuto = true
                locationManager.requestWhenInUseAuthorization()
            } else {
                UserDefaultsManagement.nightModeAuto = false
            }
            
            if nightMode == .disabled {
                UIApplication.shared.statusBarStyle = .default
                NightNight.theme = .normal
            }
            
            if nightMode == .enabled {
                UIApplication.shared.statusBarStyle = .lightContent
                NightNight.theme = .night
            }
            
            if nightMode == .brightness {
                NotificationCenter.default.post(name: NSNotification.Name.UIScreenBrightnessDidChange, object: nil)
            }
            
            tableView.reloadData()
            
            guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let vc = pageController.orderedViewControllers[0] as? ViewController  else {
                return
            }
            
            vc.sidebarTableView.sidebar = Sidebar()
            vc.sidebarTableView.reloadData()
            vc.notesTable.reloadData()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
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
    
    @objc func didChangeBrightnessSlider(sender: UISlider) {
        UserDefaultsManagement.maxNightModeBrightnessLevel = sender.value
        NotificationCenter.default.post(name: NSNotification.Name.UIScreenBrightnessDidChange, object: nil)
    }
}
