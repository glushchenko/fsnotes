//
//  DefaultExtensionControllerView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/28/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class DefaultExtensionViewController: UITableViewController {
    private var sections = [
        NSLocalizedString("Container", comment: "Settings"),
        NSLocalizedString("Extension", comment: "Settings"),
        NSLocalizedString("Files Naming", comment: "Settings"),
    ]

    private var rowsInSection = [1, 3, 4]

    private var extensions = ["markdown", "md", "txt"]

    private var naming = [
        NSLocalizedString("Auto Rename By Title", comment: "Settings"),
        NSLocalizedString("Format: Untitled Note", comment: "Settings"),
        NSLocalizedString("Format: yyyyMMddHHmmss", comment: "Settings"),
        NSLocalizedString("Format: yyyy-MM-dd hh.mm.ss a", comment: "Settings"),
    ]
    
    override func viewDidLoad() {
        self.title = NSLocalizedString("Files", comment: "Settings")
    }
    
    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath), let label = cell.textLabel, let ext = label.text {
            if indexPath.section == 1 {
                
                UserDefaultsManagement.noteExtension = ext
                UserDefaultsManagement.fileFormat = NoteType.withExt(rawValue: ext)

                for index in 0...rowsInSection[indexPath.section] {
                    let indexPath = IndexPath(row: index, section: 1)
                    if let cell = tableView.cellForRow(at: indexPath) {
                        cell.accessoryType = .none
                        tableView.deselectRow(at: indexPath, animated: false)
                    }
                }

                cell.accessoryType = .checkmark
            } else if indexPath.section == 2 {
                for index in 0...rowsInSection[indexPath.section] {
                    let indexPath = IndexPath(row: index, section: 2)
                    if let cell = tableView.cellForRow(at: indexPath) {
                        cell.accessoryType = .none
                        tableView.deselectRow(at: indexPath, animated: false)
                    }
                }

                if let id = SettingsFilesNaming(rawValue: cell.tag) {
                    UserDefaultsManagement.naming = id
                    cell.accessoryType = .checkmark
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let text = cell.textLabel?.text else { return }

        if indexPath.section == 1 {
            if UserDefaultsManagement.noteExtension == text {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        } else if indexPath.section == 2 {
            if UserDefaultsManagement.naming == SettingsFilesNaming(rawValue: cell.tag) {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = UITableViewCell()
        if indexPath.section == 0 {
            let uiSwitch = UISwitch()
            uiSwitch.addTarget(self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)
            uiSwitch.isOn = UserDefaultsManagement.fileContainer == .textBundle || UserDefaultsManagement.fileContainer == .textBundleV2

            cell.textLabel?.text = "Textbundle"
            cell.accessoryView = uiSwitch
        } else if indexPath.section == 1 {
            cell.textLabel?.text = extensions[indexPath.row]
        } else if indexPath.section == 2 {
            cell.textLabel?.text = naming[indexPath.row]
            cell.tag = indexPath.row + 1
        }

        return cell
    }

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell else { return }
        guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
        
        UserDefaultsManagement.fileContainer = uiSwitch.isOn ? .textBundleV2 : .none
    }
}
