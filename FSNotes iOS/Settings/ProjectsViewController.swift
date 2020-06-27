//
//  ProjectsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/20/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight
import CoreServices

class ProjectsViewController: UITableViewController, UIDocumentPickerDelegate {
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

        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        let addProject = Buttons.getAdd(target: self, selector: #selector(newAlert))

        var buttons = [UIBarButtonItem]()
        buttons.append(addProject)

        if #available(iOS 13.0, *) {
            let external = Buttons.getAttach(target: self, selector: #selector(attachExternal))

            buttons.append(external)
        }

        self.navigationItem.rightBarButtonItems = buttons

        self.projects = Storage.sharedInstance().getProjects()
        self.title = NSLocalizedString("Projects", comment: "Settings")

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
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
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

            let storage = Storage.shared()
            let project = Project(
                storage: storage,
                url: newDir,
                label: name,
                isTrash: false,
                isRoot: false,
                parent: self.projects.first!,
                isDefault: false,
                isArchive: false
            )

            storage.assignTree(for: project)
            self.tableView.reloadData()

            if let mvc = self.getMainVC() {
                mvc.sidebarTableView.insertRows(projects: [project])
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

    public func getMainVC() -> ViewController? {
        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = pc.containerController.viewControllers[0] as? ViewController
        else { return nil }

        return vc
    }

    private func delete(project: Project) {
        if project.isExternal {
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
        Storage.sharedInstance().removeBy(project: project)

        if let vc = self.getMainVC() {
            vc.reloadNotesTable() {
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

            let storage = Storage.sharedInstance()
            let project = Project(
                storage: storage,
                url: url,
                label: url.lastPathComponent,
                isTrash: false,
                isRoot: true,
                isDefault: false,
                isArchive: false,
                isExternal: true
            )

            storage.assignTree(for: project)
            storage.loadLabel(project, loadContent: true)

            UIApplication.getVC().sidebarTableView.insertRows(projects: [project])

            self.projects.append(project)
            self.tableView.reloadData()
        } catch {
            print(error)
        }
    }
}
