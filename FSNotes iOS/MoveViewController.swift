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

        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        self.navigationItem.rightBarButtonItem = Buttons.getAdd(target: self, selector: #selector(newAlert))

        self.projects = Storage.sharedInstance().getProjects()
        self.title = NSLocalizedString("Move", comment: "Move view")

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let vc = notesTableView.viewDelegate else { return }

        if let projects = self.projects {
            let project = projects[indexPath.row]

            for note in selectedNotes {
                let dstURL = project.url.appendingPathComponent(note.name)

                if note.project != project {
                    note.moveImages(to: project)

                    vc.sidebarTableView.removeTags(in: [note])
                    
                    guard note.move(to: dstURL) else {
                        let alert = UIAlertController(title: "Oops 👮‍♂️", message: NSLocalizedString("File with this name already exist", comment: ""), preferredStyle: UIAlertController.Style.alert)
                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        
                        note.moveImages(to: note.project)
                        return
                    }

                    note.url = dstURL
                    note.parseURL()
                    note.project = project

                    self.notesTableView.removeRows(notes: [note])
                    vc.notesTable.insertRows(notes: [note])
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
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
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
        let alertController = UIAlertController(title: NSLocalizedString("Folder name:", comment: ""), message: nil, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.placeholder = ""
        }

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            guard let allProjects = self.projects, allProjects.first(where: { $0.label == name } ) == nil else {
                let alert = UIAlertController(title: "Oops 👮‍♂️", message: NSLocalizedString("Folder with this name already exist", comment: ""), preferredStyle: UIAlertController.Style.alert)
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

            let storage = Storage.shared()

            let project = Project(
                storage: storage,
                url: newDir,
                label: name,
                isTrash: false,
                isRoot: false,
                parent: allProjects[0],
                isDefault: false,
                isArchive: false
            )

            self.projects?.append(project)
            self.tableView.reloadData()

            storage.assignTree(for: project)

            if let vc = self.notesTableView.viewDelegate {
                vc.sidebarTableView.insertRows(projects: [project])
            }
        }

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)

    }

    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
    }

}
