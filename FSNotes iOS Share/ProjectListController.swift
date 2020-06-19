//
//  ProjectListController.swift
//  FSNotes iOS Share Extension
//
//  Created by Oleksandr Glushchenko on 12/16/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class ProjectListController: UITableViewController {
    public weak var delegate: ShareViewController?
    public var projects = [Project]()

    override func viewDidLoad() {
        //title = "Append to"
    }

    public func setProjects(projects: [Project]) {
        self.projects = projects.sorted(by: {
            return $0.label < $1.label
        })
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.projects.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = self.projects[indexPath.row].label

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            UserDefaultsManagement.lastSelectedURL = projects[indexPath.row].url

            cell.accessoryType = .checkmark

            let project = self.projects[indexPath.row]

            delegate?.loadNotesFrom(project: project)
            delegate?.currentProject = self.projects[indexPath.row]
            delegate?.projectItem?.value = project.label

            self.navigationController?.popViewController(animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        if delegate?.currentProject == self.projects[indexPath.row] {
            cell.accessoryType = .checkmark
        }
    }
}
