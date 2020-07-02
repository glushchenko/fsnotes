//
//  ProjectSettingsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class ProjectSettingsViewController: UITableViewController {
    private var dismiss: Bool = false
    private var project: Project
    private var sections = [
        NSLocalizedString("Sort by", comment: ""),
        NSLocalizedString("Visibility", comment: ""),
        NSLocalizedString("Notes list", comment: "")
    ]
    private var rowsInSections = [3, 2, 1]

    init(project: Project, dismiss: Bool = false) {
        self.project = project
        self.dismiss = dismiss
        
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)

        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header

        if dismiss {
            self.navigationItem.rightBarButtonItem = Buttons.getDone(target: self, selector: #selector(close))
        } else {
            self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))
        }

        self.title = NSLocalizedString("Project", comment: "Settings") + " \"\(project.getFullLabel())\""

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = UIApplication.getVC()

        if let cell = tableView.cellForRow(at: indexPath) {
            if indexPath.section == 0x00 {
                for row in 0...rowsInSections[indexPath.section] {
                    let cell = tableView.cellForRow(at: IndexPath(row: row, section: indexPath.section))
                    cell?.accessoryType = .none
                }

                if let sort = SortBy(rawValue: cell.reuseIdentifier!) {
                    self.project.sortBy = sort
                    vc.reloadNotesTable()
                }

                if cell.accessoryType == .none {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            }
        }

        project.saveSettings()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowsInSections[section]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uiSwitch = UISwitch()
        uiSwitch.addTarget(self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)
        
        var cell = UITableViewCell()

        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                cell = UITableViewCell(style: .default, reuseIdentifier: "modificationDate")
                cell.textLabel?.text = NSLocalizedString("Modification date", comment: "")
                if project.sortBy.rawValue == "modificationDate" {
                    cell.accessoryType = .checkmark
                }
                break
            case 1:
                cell = UITableViewCell(style: .default, reuseIdentifier: "creationDate")
                cell.textLabel?.text = NSLocalizedString("Creation date", comment: "")

                if project.sortBy.rawValue == "creationDate" {
                    cell.accessoryType = .checkmark
                }
                break
            case 2:
                cell = UITableViewCell(style: .default, reuseIdentifier: "title")
                cell.textLabel?.text = NSLocalizedString("Title", comment: "")

                if project.sortBy.rawValue == "title" {
                    cell.accessoryType = .checkmark
                }
                break
            default:
                break
            }
        }

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = project.showInCommon
                uiSwitch.isEnabled =
                    !project.isDefault
                    && !project.isArchive
                    && !project.isTrash
                    && !project.isVirtual

                cell.textLabel?.text = NSLocalizedString("Show notes in \"Notes\" and \"Todo\" lists", comment: "")
            case 1:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = project.showInSidebar
                uiSwitch.isEnabled =
                    !project.isDefault
                    && !project.isArchive
                    && !project.isTrash
                    && !project.isVirtual

                cell.textLabel?.text = NSLocalizedString("Show folder in sidebar", comment: "")
            default:
                return cell
            }
        }

        if indexPath.section == 0x02 {
            cell.accessoryView = uiSwitch
            uiSwitch.isOn = project.firstLineAsTitle
            uiSwitch.isEnabled = !project.isVirtual

            cell.textLabel?.text = NSLocalizedString("Use first line as title", comment: "")
        }

        return cell
    }

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell,
            let tableView = cell.superview as? UITableView,
            let indexPath = tableView.indexPath(for: cell) else { return }

        let vc = UIApplication.getVC()

        if indexPath.section == 0x01 {
            if indexPath.row == 0x00 {
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                self.project.showInCommon = uiSwitch.isOn

                vc.reloadNotesTable()
            } else {
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }

                project.showInSidebar = uiSwitch.isOn

                if !uiSwitch.isOn {
                    let at = IndexPath(row: 0, section: 0)
                    vc.sidebarTableView.tableView(vc.sidebarTableView, didSelectRowAt: at)
                    vc.sidebarTableView.removeRows(projects: [project])
                } else {
                    vc.sidebarTableView.insertRows(projects: [project])
                }
            }
        } else if indexPath.section == 0x02 {
            guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
            project.firstLineAsTitle = uiSwitch.isOn

            let notes = Storage.sharedInstance().getNotesBy(project: project)
            for note in notes {
                note.invalidateCache()
            }

            vc.reloadNotesTable()
        }

        project.saveSettings()
    }

    @objc func cancel() {
        navigationController?.popViewController(animated: true)
    }

    @objc func close() {
        dismiss(animated: true, completion: nil)
    }
}

