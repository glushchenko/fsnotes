//
//  MoveViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/8/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class MoveViewController: UITableViewController {
    private var projects: [Project]?

    private var selectedNotes: [Note]
    private var notesTableView: NotesTableView

    init(notes: [Note], notesTableView: NotesTableView) {
        self.selectedNotes = notes
        self.notesTableView = notesTableView

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
        self.title = "Move"

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let projects = self.projects {
            let project = projects[indexPath.row]

            for note in selectedNotes {
                let dstURL = project.url.appendingPathComponent(note.name)

                if note.project != project {
                    guard note.move(to: dstURL) else {
                        let alert = UIAlertController(title: "Oops 👮‍♂️", message: "File with this name already exist", preferredStyle: UIAlertController.Style.alert)
                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        return
                    }

                    note.url = dstURL
                    note.parseURL()
                    note.project = project

                    self.notesTableView.removeByNotes(notes: [note])
                    self.notesTableView.viewDelegate?.notesTable.insertRow(note: note)
                }
            }
            
            self.notesTableView.viewDelegate?.updateNotesCounter()
        }

        self.dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()

        if let projects = self.projects {
            let project = projects[indexPath.row]
            if !project.isTrash || !project.isArchive {
                cell.textLabel?.text = project.getFullLabel()
            }
        }

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let projects = self.projects {
            return projects.count
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

        if selectedNotes.count == 1 {
            let note = selectedNotes.first!
            if let projects = self.projects {
                if projects[indexPath.row] == note.project {
                    cell.accessoryType = .checkmark
                }
            }
        }
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

            guard let allProjects = self.projects, allProjects.first(where: { $0.label == name } ) == nil else {
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

            let project = Project(url: newDir, label: name, isTrash: false, isRoot: false, parent: allProjects[0], isDefault: false, isArchive: false)

            self.projects?.append(project)
            self.tableView.reloadData()

            _ = Storage.sharedInstance().add(project: project)

            self.notesTableView.viewDelegate?.sidebarTableView.reloadProjectsSection()
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)

    }

    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
    }

}
