//
//  TagsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/8/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class TagsViewController: UITableViewController {
    private var tags: [String]?

    private var selectedNote: Note
    private var notesTableView: NotesTableView

    init(note: Note, notesTableView: NotesTableView) {
        self.selectedNote = note
        self.notesTableView = notesTableView

        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: MixedColor(normal: 0x000000, night: 0xfafafa)]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = MixedColor(normal: 0xfafafa, night: 0x47444e)

        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.plain, target: self, action: #selector(MoveViewController.cancel))

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: UIBarButtonItemStyle.plain, target: self, action: #selector(MoveViewController.newAlert))

        self.tags = Storage.sharedInstance().getTags()
        self.title = "Tags"

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let tags = self.tags {
            let tag = tags[indexPath.row]

            if let cell = tableView.cellForRow(at: indexPath) {
                if cell.accessoryType == .none {
                    self.selectedNote.addTag(tag)
                    cell.accessoryType = .checkmark
                } else {
                    self.selectedNote.removeTag(tag)
                    cell.accessoryType = .none
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()

        if let tags = self.tags {
            let tag = tags[indexPath.row]
            cell.textLabel?.text = tag
        }

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let tags = self.tags {
            return tags.count
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

        if let tags = self.tags {
            if self.selectedNote.tagNames.contains(tags[indexPath.row]) {
                cell.accessoryType = .checkmark
            }
        }
    }

    @objc func newAlert() {
        let alertController = UIAlertController(title: "Tag name:", message: nil, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.placeholder = ""
        }

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            guard let tags = self.tags, !tags.contains(name) else {
                let alert = UIAlertController(title: "Oops 👮‍♂️", message: "Tag with this name already exist", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))

                self.present(alert, animated: true, completion: nil)
                return
            }

            Storage.sharedInstance().addTag(name)
            self.tags?.insert(name, at: 0)

            self.notesTableView.viewDelegate?.sidebarTableView.sidebar = Sidebar()
            self.notesTableView.viewDelegate?.sidebarTableView.reloadData()

            self.tableView.reloadData()
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
