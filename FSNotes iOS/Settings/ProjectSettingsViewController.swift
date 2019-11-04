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
    private var sections = ["Sort by", "Visibility", "Notes list"]
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
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x2e2c32)

        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header

        if dismiss {
            self.navigationItem.rightBarButtonItem = Buttons.getDone(target: self, selector: #selector(close))
        } else {
            self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))
        }

        self.title = "Project \"\(project.getFullLabel())\""

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if let cell = tableView.cellForRow(at: indexPath) {
            let vc = UIApplication.getVC()

            if indexPath.section == 0x00 {
                for row in 0...rowsInSections[indexPath.section] {
                    let cell = tableView.cellForRow(at: IndexPath(row: row, section: indexPath.section))
                    cell?.accessoryType = .none
                }

                if let sort = SortBy(rawValue: cell.reuseIdentifier!) {
                    self.project.sortBy = sort
                    
                    vc.updateTable {}
                }
            } else if indexPath.section == 0x01 {
                if indexPath.row == 0x00 {
                    self.project.showInCommon = cell.accessoryType == .none

                    vc.updateTable {}
                } else {
                    self.project.showInSidebar = cell.accessoryType == .none

                    vc.sidebarTableView.reloadData()
                    vc.reloadSidebar()
                }
            } else {
                self.project.firstLineAsTitle = cell.accessoryType == .none

                let notes = Storage.sharedInstance().getNotesBy(project: self.project)

                for note in notes {
                    note.invalidateCache()
                }

                vc.updateTable {}
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
        return 3
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
                cell.textLabel?.text = "Show notes in \"Notes\" and \"Todo\" lists"
                cell.accessoryType = project.showInCommon ? .checkmark : .none
            case 1:
                cell.textLabel?.text = "Show folder in sidebar"
                cell.accessoryType = project.showInSidebar ? .checkmark : .none
            default:
                return cell
            }
        }

        if indexPath.section == 0x02 {
            cell.textLabel?.text = "Use first line as title"
            cell.accessoryType = project.firstLineAsTitle ? .checkmark : .none
        }

        return cell
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc func close() {
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let vc = pageController.mainViewController
            else { return }

        vc.sidebarTableView.reloadProjectsSection()
        vc.notesTable.reloadData()

        self.dismiss(animated: true, completion: nil)
    }
}

