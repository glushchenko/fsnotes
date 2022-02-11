//
//  DefaultExtensionControllerView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/28/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class DefaultExtensionViewController: UITableViewController {
    private var sections = [
        NSLocalizedString("Container", comment: ""),
        NSLocalizedString("Extension", comment: "")
    ]

    private var rowsInSection = [1, 4]

    private var extensions = ["markdown", "md", "txt", "rtf"]
    
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        self.title = NSLocalizedString("Default Extension", comment: "Settings")
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
            UserDefaultsManagement.noteExtension = ext
            UserDefaultsManagement.fileFormat = NoteType.withExt(rawValue: ext)

            self.navigationController?.popViewController(animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

        guard let text = cell.textLabel?.text else { return }

        if UserDefaultsManagement.noteExtension == text {
            cell.accessoryType = .checkmark
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

            let view = UIView()
            view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
            cell.selectedBackgroundView = view
        } else if indexPath.section == 1 {
            cell.textLabel?.text = extensions[indexPath.row]

            let view = UIView()
            view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
            cell.selectedBackgroundView = view
        }

        return cell
    }

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell else { return }
        guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
        
        UserDefaultsManagement.fileContainer = uiSwitch.isOn ? .textBundleV2 : .none
    }
}
