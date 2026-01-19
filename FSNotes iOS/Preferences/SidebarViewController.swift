//
//  SidebarViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 08.03.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class SidebarViewController: UITableViewController {
    private var rows = [
        NSLocalizedString("Inbox", comment: ""),
        NSLocalizedString("Todo", comment: ""),
        NSLocalizedString("Untagged", comment: ""),
        NSLocalizedString("Trash", comment: ""),
    ]

    override func viewDidLoad() {
        self.title = NSLocalizedString("Library", comment: "Settings")

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = rows[indexPath.row]

        let uiSwitch = UISwitch()
        uiSwitch.addTarget(self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)

        switch indexPath.row {
        case 0:
            uiSwitch.isOn = UserDefaultsManagement.sidebarVisibilityInbox
            break
        case 1:
            uiSwitch.isOn = UserDefaultsManagement.sidebarVisibilityTodo
            break
        case 2:
            uiSwitch.isOn = UserDefaultsManagement.sidebarVisibilityUntagged
            break
        case 3:
            uiSwitch.isOn = UserDefaultsManagement.sidebarVisibilityTrash
            break
        default:
            break
        }

        cell.accessoryView = uiSwitch

        return cell
    }

    @objc func cancel() {
        navigationController?.popViewController(animated: true)
    }

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell,
            let tableView = cell.superview as? UITableView,
            let indexPath = tableView.indexPath(for: cell) else { return }

        guard let uiSwitch = cell.accessoryView as? UISwitch else { return }

        switch indexPath.row {
        case 0:
            UserDefaultsManagement.sidebarVisibilityInbox = uiSwitch.isOn
        case 1:
            UserDefaultsManagement.sidebarVisibilityTodo = uiSwitch.isOn
        case 2:
            UserDefaultsManagement.sidebarVisibilityUntagged = uiSwitch.isOn
        case 3:
            UserDefaultsManagement.sidebarVisibilityTrash = uiSwitch.isOn
        default:
            return
        }

        UIApplication.getVC().sidebarTableView.reloadSidebar()
    }
}
