//
//  NotesListController.swift
//  FSNotes iOS Share Extension
//
//  Created by Oleksandr Glushchenko on 10/26/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class NotesListController: UITableViewController {
    public var delegate: ShareViewController?
    private var notes = [Note]()

    override func viewDidLoad() {
        title = "Append to"
    }

    public func setNotes(notes: [Note]) {
        self.notes = notes
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.notes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = self.notes[indexPath.row].title

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let note = self.notes[indexPath.row]
        note.loadContent()
        delegate?.save(note: note)
    }
}
