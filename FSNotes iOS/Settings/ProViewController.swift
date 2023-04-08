//
//  ProViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 19.02.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class ProViewController: UITableViewController {
    private var sections = [
        NSLocalizedString("+", comment: "Settings"),
        NSLocalizedString("View", comment: "Settings"),
    ]

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }

    private var rows = [
        [
            NSLocalizedString("Default keyboard in editor", comment: ""),
            NSLocalizedString("Use inline tags", comment: "")
        ], [
            NSLocalizedString("Sort by", comment: ""),
            NSLocalizedString("Sidebar", comment: "")
        ]
    ]

    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        self.title = NSLocalizedString("Advanced", comment: "Settings")
        super.viewDidLoad()
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                self.navigationController?.pushViewController(SortByViewController(), animated: true)
            } else {
                self.navigationController?.pushViewController(SidebarViewController(), animated: true)
            }
        }

        if indexPath.section == 0, indexPath.row == 0 {
            self.navigationController?.pushViewController(LanguageViewController(), animated: true)
        }

        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uiSwitch = UISwitch()
        uiSwitch.addTarget(self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)

        let cell = UITableViewCell()
        cell.textLabel?.text = rows[indexPath.section][indexPath.row]

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        if indexPath.section == 0 {
            switch indexPath.row {
            case 1:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.inlineTags
                break
            default:
                break
            }
        }

        if indexPath.section == 1 {
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows[section].count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

        if indexPath.row == 0 {
            cell.accessoryType = .disclosureIndicator
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            if NightNight.theme == .night {
                headerView.textLabel?.textColor = UIColor(red: 0.48, green: 0.48, blue: 0.51, alpha: 1.00)
            } else {
                headerView.textLabel?.textColor = UIColor(red: 0.47, green: 0.47, blue: 0.48, alpha: 1.00)
            }
        }
    }

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell,
            let tableView = cell.superview as? UITableView,
            let indexPath = tableView.indexPath(for: cell) else { return }


        switch indexPath.row {
        case 1:
            guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
            UserDefaultsManagement.inlineTags = uiSwitch.isOn

            let vc = UIApplication.getVC()
            if UserDefaultsManagement.inlineTags {
                vc.sidebarTableView.loadAllTags()
            } else {
                vc.sidebarTableView.unloadAllTags()
            }

            vc.resizeSidebar(withAnimation: true)

            UIApplication.getEVC().resetToolbar()
        default:
            return
        }
    }

    private func autoVersioningPrompt() {
        let title = NSLocalizedString("Сlearing history", comment: "")
        let message = NSLocalizedString("Are you sure you want to delete the history of all notes?", comment: "")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "OK", style: .default) { (_) in
            let revisions = Storage.shared().getRevisionsHistoryDocumentsSupport()
            do {
                try FileManager.default.removeItem(at: revisions)
            } catch {
                print("History clear: \(error)")
            }

            self.dismiss(animated: true)
        })

        let cancel = NSLocalizedString("Cancel", comment: "")
        alert.addAction(UIAlertAction(title: cancel, style: .cancel, handler: { (action: UIAlertAction!) in
        }))

        self.present(alert, animated: true, completion: nil)
    }
}
