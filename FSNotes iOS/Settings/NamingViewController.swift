//
//  FilesNamingController.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 16.06.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class NamingViewController: UITableViewController {
    private var filesNaming: [String] = [
        "UUID",
        NSLocalizedString("Auto Rename By Title", comment: "Settings")
    ]

    override func viewDidLoad() {
        title = NSLocalizedString("Files Naming", comment: "Settings")
        super.viewDidLoad()
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserDefaultsManagement.naming = SettingsFilesNaming(rawValue: indexPath.row)!

        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = filesNaming[indexPath.row]

        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filesNaming.count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == UserDefaultsManagement.naming.rawValue {
            cell.accessoryType = .checkmark
        }
    }
}
