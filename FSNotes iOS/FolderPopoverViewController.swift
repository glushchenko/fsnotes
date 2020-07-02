//
//  FolderPopoverViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/7/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class FolderPopoverViewControler : UITableViewController, UIDocumentPickerDelegate {
    public var actions: [FolderPopoverActions] = [FolderPopoverActions]()

    override func viewDidLoad() {
        tableView.rowHeight = 44
        tableView.separatorInset = UIEdgeInsets.zero
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()

        let action = actions[indexPath.row]
        cell.textLabel?.text = action.getDescription()
        cell.textLabel?.textAlignment = .center

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let action = actions[indexPath.row]

        switch action {
        case .importNote:
            importNote()
        case .settingsFolder:
            openSettings()
        case .createFolder:
            createFolder()
        case .removeFolder:
            removeFolder()
        case .renameFolder:
            renameFolder()
        case .removeTag:
            removeTag()
        case .renameTag:
            renameTag()
        }
    }

    public func setActions(_ actions: [FolderPopoverActions]) {
        self.actions = actions
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        guard var projectURL = Storage.sharedInstance().getCurrentProject()?.url else { return }

        if let mvc = getVC(), let pURL = mvc.sidebarTableView.getSidebarItem()?.project?.url {
            projectURL = pURL
        }

        for url in urls {
            let dstURL = projectURL.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dstURL)
        }

        self.dismiss(animated: true, completion: nil)
    }

    private func getVC() -> ViewController? {
        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = pc.containerController.viewControllers[0] as? ViewController
        else { return nil }

        return vc
    }

    private func importNote() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        if #available(iOS 11.0, *) {
            picker.allowsMultipleSelection = true
        }
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }



    private func openSettings() {
        guard let vc = getVC(),
            let sidebarItem = vc.sidebarTableView.getSidebarItem()
        else { return }

        let storage = Storage.shared()

        // All projects

        var currentProject = sidebarItem.project
        if currentProject == nil {
            currentProject = storage.getCurrentProject()
        }

        // Virtual projects Notes and Todo

        if sidebarItem.type == .Todo || sidebarItem.type == .All {
            currentProject = sidebarItem.project
        }

        guard let project = currentProject else { return }

        let projectController = ProjectSettingsViewController(project: project, dismiss: true)
        let controller = UINavigationController(rootViewController: projectController)

        self.dismiss(animated: true, completion: nil)
        vc.present(controller, animated: true, completion: nil)
    }

    private func createFolder() {
        guard let mvc = getVC(),
            let selectedProject = mvc.searchQuery.project
        else { return }

        let alertController = UIAlertController(title: NSLocalizedString("Create folder:", comment: ""), message: nil, preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            [] (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Enter folder name", comment: "")
        })

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            let newDir = selectedProject.url.appendingPathComponent(name, isDirectory: true)

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
                parent: selectedProject,
                isDefault: false,
                isArchive: false
            )

            storage.assignTree(for: project)
            mvc.sidebarTableView.insertRows(projects: [project])
        }

        let title = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: title, style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.dismiss(animated: true, completion: nil)
        mvc.present(alertController, animated: true) {
            alertController.textFields![0].selectAll(nil)
        }
    }

    private func removeFolder() {
        guard let mvc = getVC(),
            let selectedProject = mvc.searchQuery.project
        else { return }

        let alert = UIAlertController(
            title: "Folder removing 🚨",
            message: "Are you really want to remove \"\(selectedProject.label)\"? Folder content will be deleted, action can not be undone.",
            preferredStyle: UIAlertController.Style.alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction!) in

            mvc.sidebarTableView.removeRows(projects: [selectedProject])
            try? FileManager.default.removeItem(at: selectedProject.url)
            Storage.shared().remove(project: selectedProject)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
        }))

        self.dismiss(animated: true, completion: nil)
        mvc.present(alert, animated: true, completion: nil)
    }

    private func renameFolder() {
        guard let mvc = getVC(),
            let selectedProject = mvc.searchQuery.project
        else { return }

        let title = NSLocalizedString("Rename folder:", comment: "Popover table")
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            [] (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Enter folder name", comment: "")
            textField.text = selectedProject.url.lastPathComponent
        })

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            let newDir = selectedProject.url
                .deletingLastPathComponent()
                .appendingPathComponent(name, isDirectory: true)

            do {
                try FileManager.default.moveItem(at: selectedProject.url, to: newDir)
            } catch {
                print(error)
                return
            }

            mvc.sidebarTableView.removeRows(projects: [selectedProject])
            mvc.storage.unload(project: selectedProject)

            selectedProject.url = newDir
            selectedProject.loadLabel()

            mvc.storage.loadLabel(selectedProject)
            mvc.sidebarTableView.insertRows(projects: [selectedProject])
            mvc.sidebarTableView.select(project: selectedProject)
        }

        let cancel = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: cancel, style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.dismiss(animated: true, completion: nil)
        mvc.present(alertController, animated: true) {
            alertController.textFields![0].selectAll(nil)
        }
    }

    private func removeTag() {
        guard let mvc = getVC(),
            let selectedProject = mvc.searchQuery.project,
            let tag = mvc.searchQuery.tag
        else { return }

        let notes =
            mvc.storage.noteList
                .filter({ $0.project == selectedProject })
                .filter({ $0.tags.contains(tag) })

        for note in notes {
            note.replace(tag: "#\(tag)", with: "")
            note.tags.removeAll(where: { $0 == tag })
        }

        mvc.sidebarTableView.remove(tag: tag)
        self.dismiss(animated: true, completion: nil)
    }

    private func renameTag() {
        guard let mvc = getVC(),
            let selectedProject = mvc.searchQuery.project,
            let tag = mvc.searchQuery.tag
        else { return }

        let title = NSLocalizedString("Rename tag:", comment: "Popover table")
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            [] (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Enter new tag name", comment: "")
            textField.text = tag
        })

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard var name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            name = name.withoutSpecialCharacters

            guard name.count > 1 else { return }

            let notes =
                mvc.storage.noteList
                    .filter({ $0.project == selectedProject })
                    .filter({ $0.tags.contains(tag) })

            for note in notes {
                note.replace(tag: "#\(tag)", with: "#\(name)")
                note.tags.removeAll(where: { $0 == tag })
                _ = note.scanContentTags()
            }

            mvc.sidebarTableView.remove(tag: tag)
            mvc.sidebarTableView.insert(tags: [name])

            self.dismiss(animated: true, completion: nil)
        }

        let cancel = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: cancel, style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.dismiss(animated: true, completion: nil)
        mvc.present(alertController, animated: true) {
            alertController.textFields![0].selectAll(nil)
        }
    }
}

enum FolderPopoverActions: Int {
    case importNote
    case settingsFolder
    case createFolder
    case removeFolder
    case renameFolder
    case removeTag
    case renameTag

    static let description =
        [
            NSLocalizedString("Import notes", comment: "Main view popover table"),
            NSLocalizedString("View settings", comment: "Main view popover table"),
            NSLocalizedString("Create folder", comment: "Main view popover table"),
            NSLocalizedString("Remove folder", comment: "Main view popover table"),
            NSLocalizedString("Rename folder", comment: "Main view popover table"),
            NSLocalizedString("Remove tag", comment: "Main view popover table"),
            NSLocalizedString("Rename tag", comment: "Main view popover table")
        ]

    public func getDescription() -> String {
        return FolderPopoverActions.description[self.rawValue]
    }
}
