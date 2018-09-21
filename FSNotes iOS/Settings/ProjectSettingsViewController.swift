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
    private var project: Project
    private var sections = ["Sort by", "Visibility"]
    private var rowsInSections = [3, 2]

    init(project: Project) {
        self.project = project
        
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x2e2c32)

        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        self.title = "Project \"\(project.getFullLabel())\""

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0x00 {
            for row in 0...rowsInSections[indexPath.section] {
                let cell = tableView.cellForRow(at: IndexPath(row: row, section: indexPath.section))
                cell?.accessoryType = .none
            }
        }

        if let cell = tableView.cellForRow(at: indexPath) {
            let vc = UIApplication.getVC()

            if indexPath.section == 0x00 {
                if let sort = SortBy(rawValue: cell.reuseIdentifier!) {
                    self.project.sortBy = sort
                    
                    vc.updateTable {}
                }
            } else {
                if indexPath.row == 0x00 {
                    self.project.showInCommon = cell.accessoryType == .none

                    vc.updateTable {}
                } else {
                    self.project.showInSidebar = cell.accessoryType == .none

                    vc.sidebarTableView.reloadData()
                    vc.reloadSidebar()
                }
            }

            if cell.accessoryType == .none {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }

        self.project.saveSettings()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowsInSections[section]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section]
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        let vc = UIApplication.getVC()

        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                cell = UITableViewCell(style: .default, reuseIdentifier: "modificationDate")
                cell.textLabel?.text = "Modification date"
                if project.sortBy.rawValue == "modificationDate" {
                    cell.accessoryType = .checkmark
                }
                break
            case 1:
                cell = UITableViewCell(style: .default, reuseIdentifier: "creationDate")
                cell.textLabel?.text = "Creation date"

                if project.sortBy.rawValue == "creationDate" {
                    cell.accessoryType = .checkmark
                }
                break
            case 2:
                cell = UITableViewCell(style: .default, reuseIdentifier: "title")
                cell.textLabel?.text = "Title"

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
                cell.textLabel?.text = "Show notes in main \"Notes\" list"
                cell.accessoryType = project.showInCommon ? .checkmark : .none
            case 1:
                cell.textLabel?.text = "Show folder in sidebar"
                cell.accessoryType = project.showInSidebar ? .checkmark : .none
            default:
                return cell
            }
        }

        return cell
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }
}

