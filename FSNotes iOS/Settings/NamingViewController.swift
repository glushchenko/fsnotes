//
//  FilesNamingController.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 16.06.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class NamingViewController: UITableViewController {
    private var filesNaming: [String] = [
        "UUID",
        NSLocalizedString("Auto rename by title", comment: "Naming controller")
    ]

    override func viewDidLoad() {
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header

        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        self.title = NSLocalizedString("Files Naming", comment: "Settings")
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

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filesNaming.count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

        if indexPath.row == UserDefaultsManagement.naming.rawValue {
            cell.accessoryType = .checkmark
        }
    }
}
