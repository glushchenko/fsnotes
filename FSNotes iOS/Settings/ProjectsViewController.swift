//
//  ProjectsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class ProjectsViewController: UITableViewController {
    private var projects: [Project]

    init() {
        let storage = Storage.sharedInstance()
        self.projects = storage.getProjects()

        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header

        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        self.navigationItem.rightBarButtonItem = Buttons.getAdd(target: self, selector: #selector(newAlert))

        self.projects = Storage.sharedInstance().getProjects()
        self.title = "Projects"

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let project = self.projects[indexPath.row]
        let controller = ProjectSettingsViewController(project: project)

        self.navigationController?.pushViewController(controller, animated: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()

        if self.projects.count > 0 {
            let project = projects[indexPath.row]
            if !project.isTrash || !project.isArchive {
                cell.textLabel?.text = project.getFullLabel()
            }
        }

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.projects.count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let project = self.projects[indexPath.row]

        guard !project.isRoot else { return nil }


        let deleteAction = UITableViewRowAction(style: .default, title: "Delete", handler: { (action , indexPath) -> Void in
            self.delete(project: project)
        })

        deleteAction.backgroundColor = UIColor(red:0.93, green:0.31, blue:0.43, alpha:1.0)

        return [deleteAction]
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc func newAlert() {
        let alertController = UIAlertController(title: "Folder name:", message: nil, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.placeholder = ""
        }

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            guard self.projects.first(where: { $0.label == name } ) == nil else {
                let alert = UIAlertController(title: "Oops 👮‍♂️", message: "Folder with this name already exist", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

                self.present(alert, animated: true, completion: nil)
                return
            }

            guard let newDir = UserDefaultsManagement.storageUrl?.appendingPathComponent(name) else { return }

            do {
                try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print(error)
                return
            }

            let project = Project(url: newDir, label: name, isTrash: false, isRoot: false, parent: self.projects.first!, isDefault: false, isArchive: false)

            self.projects.append(project)
            self.tableView.reloadData()

            _ = Storage.sharedInstance().add(project: project)

            if let mvc = self.getMainVC() {
                mvc.sidebarTableView.sidebar = Sidebar()
                mvc.sidebarTableView.reloadData()
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)

    }

    public func getMainVC() -> ViewController? {
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let mvc = pageController.mainViewController
        else { return nil }

        return mvc
    }

    private func delete(project: Project) {
        let message = "Are you sure you want to remove project \"\(project.getFullLabel())\" and all files inside?"

        let alertController = UIAlertController(title: "Project removing ❌", message: message, preferredStyle: .alert)

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            project.remove()

            if let i = self.projects.index(of: project) {
                self.projects.remove(at: i)
            }

            self.tableView.reloadData()
            Storage.sharedInstance().removeBy(project: project)

            if let mvc = self.getMainVC() {
                mvc.updateTable {
                    mvc.sidebarTableView.sidebar = Sidebar()
                    mvc.sidebarTableView.reloadData()
                }
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)
    }
}
