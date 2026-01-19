//
//  SortByViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 06.03.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class SortByViewController: UITableViewController {
    private var rows = [
        NSLocalizedString("Modification Date", comment: ""),
        NSLocalizedString("Creation Date", comment: ""),
        NSLocalizedString("Title", comment: "")
    ]

    override func viewDidLoad() {
        self.title = NSLocalizedString("Sort By", comment: "Settings")

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = UIApplication.getVC()

        if let cell = tableView.cellForRow(at: indexPath) {
            if indexPath.section == 0x00 {
                for row in 0...rows.count {
                    let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0))
                    cell?.accessoryType = .none
                }

                if let sort = SortBy(rawValue: cell.reuseIdentifier!) {
                    UserDefaultsManagement.sort = sort
                    vc.reloadNotesTable()
                }

                if cell.accessoryType == .none {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            }
        }

        cancel()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()

        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                cell = UITableViewCell(style: .default, reuseIdentifier: "modificationDate")
                cell.textLabel?.text = NSLocalizedString("Modification Date", comment: "")
                if UserDefaultsManagement.sort == .modificationDate {
                    cell.accessoryType = .checkmark
                }
                break
            case 1:
                cell = UITableViewCell(style: .default, reuseIdentifier: "creationDate")
                cell.textLabel?.text = NSLocalizedString("Creation Date", comment: "")

                if UserDefaultsManagement.sort == .creationDate {
                    cell.accessoryType = .checkmark
                }
                break
            case 2:
                cell = UITableViewCell(style: .default, reuseIdentifier: "title")
                cell.textLabel?.text = NSLocalizedString("Title", comment: "")

                if UserDefaultsManagement.sort == .title {
                    cell.accessoryType = .checkmark
                }
                break
            default:
                break
            }
        }

        return cell
    }

    @objc func cancel() {
        navigationController?.popViewController(animated: true)
    }

    @objc func close() {
        dismiss(animated: true, completion: nil)
    }
}

