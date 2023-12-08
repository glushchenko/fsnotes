//
//  ProjectsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import CoreServices

class ProjectsViewController: UITableViewController, UIDocumentPickerDelegate {
    private var projects: [Project]

    init() {
        let storage = Storage.shared()
        self.projects = storage.getProjects()

        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        let addProject = Buttons.getAdd(target: self, selector: #selector(newAlert))

        var buttons = [UIBarButtonItem]()
        buttons.append(addProject)

//        if #available(iOS 13.0, *) {
//            let external = Buttons.getAttach(target: self, selector: #selector(attachExternal))
//
//            buttons.append(external)
//        }

        self.navigationItem.rightBarButtonItems = buttons

        self.projects = Storage.shared().getProjects()
        self.title = NSLocalizedString("Folders", comment: "Settings")

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
            if project.isTrash {
                cell.textLabel?.text = NSLocalizedString("Trash", comment: "")
            } else {
                cell.textLabel?.text = project.getNestedLabel()
            }
        }

        cell.accessoryType = .disclosureIndicator

        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.projects.count
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let project = self.projects[indexPath.row]

        if project.isDefault {
            return nil
        }

        if project.isTrash {
            return nil
        }

        let deleteAction = UITableViewRowAction(style: .default, title: NSLocalizedString("Delete", comment: ""), handler: { (action , indexPath) -> Void in
            self.delete(project: project)
        })

        deleteAction.backgroundColor = UIColor(red:0.93, green:0.31, blue:0.43, alpha:1.0)

        return [deleteAction]
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc func newAlert() {
        let alertController = UIAlertController(title: NSLocalizedString("Folder name:", comment: ""), message: nil, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.placeholder = ""
        }

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            guard self.projects.first(where: { $0.label == name } ) == nil else {
                let alert = UIAlertController(title: "Oops 👮‍♂️", message: NSLocalizedString("Folder with this name already exist", comment: ""), preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

                self.present(alert, animated: true, completion: nil)
                return
            }

            guard let newDir = UserDefaultsManagement.storageUrl?.appendingPathComponent(name, isDirectory: true) else { return }

            do {
                try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print(error)
                return
            }

            if let projects = Storage.shared().insert(url: newDir) {
                self.tableView.reloadData()
                
                OperationQueue.main.addOperation {
                    UIApplication.getVC().sidebarTableView.insertRows(projects: projects)
                }
            }
        }

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)

    }

    @objc func attachExternal() {
        let documentPicker =
            UIDocumentPickerViewController(documentTypes: [kUTTypeFolder as String], in: .open)


        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }

    private func delete(project: Project) {
        if project.isBookmark {
            self.removeProject(project: project)

            SandboxBookmark.sharedInstance().remove(url: project.url)
            return
        }

        let message = "Are you sure you want to remove project \"\(project.getFullLabel())\" and all files inside?"

        let alertController = UIAlertController(title: NSLocalizedString("Project removing ❌", comment: ""), message: message, preferredStyle: .alert)

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            project.remove()
            self.removeProject(project: project)
        }

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)
    }

    private func removeProject(project: Project) {
        if let i = self.projects.firstIndex(of: project) {
            self.projects.remove(at: i)
        }

        self.tableView.reloadData()
        Storage.shared().removeBy(project: project)

        let vc = UIApplication.getVC()
        vc.reloadNotesTable() {
            OperationQueue.main.addOperation {
                vc.sidebarTableView.removeRows(projects: [project])
            }
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        guard urls.count == 1, let url = urls.first, url.hasDirectoryPath else { return }

        guard url.startAccessingSecurityScopedResource() else {
            return
        }

        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)

            SandboxBookmark.sharedInstance().save(data: bookmarkData)

            if let projects = Storage.shared().insert(url: url) {
                OperationQueue.main.addOperation {
                    UIApplication.getVC().sidebarTableView.insertRows(projects: projects)
                    
                    self.projects.append(contentsOf: projects)
                    self.tableView.reloadData()
                }
            }
        } catch {
            print(error)
        }
    }
}
