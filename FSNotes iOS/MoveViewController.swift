//
//  MoveViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/8/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

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
        initZeroNavigationBackground()

        self.navigationItem.rightBarButtonItem = Buttons.getAdd(target: self, selector: #selector(createFolder))

        self.projects = Storage.shared().getProjects()
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

                    note.moveHistory(src: note.url, dst: dstURL)

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
            if project.isTrash {
                cell.textLabel?.text = NSLocalizedString("Trash", comment: "")
            } else {
                cell.textLabel?.text = project.getNestedLabel()
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let projects = self.projects {
            return projects.count
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if selectedNotes.count == 1 {
            let note = selectedNotes.first!
            if let projects = self.projects {
                if projects[indexPath.row] == note.project {
                    cell.accessoryType = .checkmark
                }
            }
        }
    }

    @objc func createFolder() {
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

            if let projects = Storage.shared().insert(url: newDir) {
                OperationQueue.main.addOperation {
                    UIApplication.getVC().sidebarTableView.insertRows(projects: projects)
                    
                    self.projects?.append(contentsOf: projects)
                    self.tableView.reloadData()
                    
                    self.notesTableView.viewDelegate?.sidebarTableView.reloadSidebar()
                }
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
