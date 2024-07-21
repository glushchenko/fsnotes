//
//  ProjectSettingsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class ProjectSettingsViewController: UITableViewController {
    private var dismiss: Bool = false
    private var project: Project
    private var sections = [
        NSLocalizedString("Sort By", comment: ""),
        NSLocalizedString("Sort Direction", comment: ""),
        NSLocalizedString("Visibility", comment: ""),
        NSLocalizedString("Notes List", comment: "")
    ]
    private var rowsInSections = [4, 2, 2, 1]

    init(project: Project, dismiss: Bool = false) {
        self.project = project
        self.dismiss = dismiss
        
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        initZeroNavigationBackground()

        if dismiss {
            self.navigationItem.rightBarButtonItem = Buttons.getDone(target: self, selector: #selector(close))
        }

        self.title = project.getFullLabel()

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
                    self.project.settings.sortBy = sort
                    vc.buildSearchQuery()
                    vc.reloadNotesTable()
                }

                if cell.accessoryType == .none {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            }

            if indexPath.section == 0x01 {
                for row in 0...rowsInSections[indexPath.section] {
                    let cell = tableView.cellForRow(at: IndexPath(row: row, section: indexPath.section))
                    cell?.accessoryType = .none
                }

                if let sort = SortDirection(rawValue: cell.reuseIdentifier!) {
                    self.project.settings.sortDirection = sort
                    vc.buildSearchQuery()
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
        return 4
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uiSwitch = UISwitch()
        uiSwitch.addTarget(self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)
        
        var cell = UITableViewCell()

        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                cell = UITableViewCell(style: .default, reuseIdentifier: "none")
                cell.textLabel?.text = NSLocalizedString("None", comment: "")
                if project.settings.sortBy.rawValue == "none" {
                    cell.accessoryType = .checkmark
                }
                break
            case 1:
                cell = UITableViewCell(style: .default, reuseIdentifier: "modificationDate")
                cell.textLabel?.text = NSLocalizedString("Modification Date", comment: "")
                if project.settings.sortBy.rawValue == "modificationDate" {
                    cell.accessoryType = .checkmark
                }
                break
            case 2:
                cell = UITableViewCell(style: .default, reuseIdentifier: "creationDate")
                cell.textLabel?.text = NSLocalizedString("Creation Date", comment: "")

                if project.settings.sortBy.rawValue == "creationDate" {
                    cell.accessoryType = .checkmark
                }
                break
            case 3:
                cell = UITableViewCell(style: .default, reuseIdentifier: "title")
                cell.textLabel?.text = NSLocalizedString("Title", comment: "")

                if project.settings.sortBy.rawValue == "title" {
                    cell.accessoryType = .checkmark
                }
                break
            default:
                break
            }
        }

        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                cell = UITableViewCell(style: .default, reuseIdentifier: "asc")
                cell.textLabel?.text = NSLocalizedString("Ascending", comment: "")
                if project.settings.sortDirection.rawValue == "asc" {
                    cell.accessoryType = .checkmark
                }
                break
            case 1:
                cell = UITableViewCell(style: .default, reuseIdentifier: "desc")
                cell.textLabel?.text = NSLocalizedString("Descending", comment: "")
                if project.settings.sortDirection.rawValue == "desc" {
                    cell.accessoryType = .checkmark
                }
                break
            default:
                break
            }
        }

        if indexPath.section == 0x02 {
            switch indexPath.row {
            case 0:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = project.settings.showInCommon
                uiSwitch.isEnabled =
                    !project.isDefault
                    && !project.isTrash
                    && !project.isVirtual

                cell.textLabel?.text = NSLocalizedString("Show Notes in \"Notes\" and \"Todo\"", comment: "")
            case 1:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = project.settings.showInSidebar
                uiSwitch.isEnabled =
                    !project.isDefault
                    && !project.isTrash
                    && !project.isVirtual

                cell.textLabel?.text = NSLocalizedString("Show Folder in Library", comment: "")
            default:
                return cell
            }
        }

        if indexPath.section == 0x03 {
            cell.accessoryView = uiSwitch
            uiSwitch.isOn = project.settings.isFirstLineAsTitle()
            uiSwitch.isEnabled = !project.isVirtual

            cell.textLabel?.text = NSLocalizedString("Use First Line as Title", comment: "")
        }

        return cell
    }

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell,
            let tableView = cell.superview as? UITableView,
            let indexPath = tableView.indexPath(for: cell) else { return }

        let vc = UIApplication.getVC()

        if indexPath.section == 0x02 {
            if indexPath.row == 0x00 {
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                self.project.settings.showInCommon = uiSwitch.isOn

                vc.reloadNotesTable()
            } else {
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }

                self.project.settings.showInSidebar = uiSwitch.isOn

                OperationQueue.main.addOperation {
                    if !uiSwitch.isOn {
                        let at = IndexPath(row: 0, section: 0)
                        vc.sidebarTableView.tableView(vc.sidebarTableView, didSelectRowAt: at)
                        vc.sidebarTableView.removeRows(projects: [self.project])
                    } else {
                        vc.sidebarTableView.insertRows(projects: [self.project])
                    }
                }
            }
        } else if indexPath.section == 0x03 {
            guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
            project.settings.firstLineAsTitle = uiSwitch.isOn

            let notes = Storage.shared().getNotesBy(project: project)
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

