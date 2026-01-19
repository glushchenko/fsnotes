//
//  AppIconViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Hlushchenko on 07.04.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit

class AppIconViewController: UITableViewController {
    enum AppIconRows: Int, CaseIterable {
        case modern
        case classic
        case ny2026

        public func getName() -> String {
            switch self {
            case .modern:
                return "Modern"
            case .classic:
                return "Classic"
            case .ny2026:
                return "Neo"
            }
        }

        var description : String {
            switch self {
            case .modern: return "modern"
            case .classic: return "classic-2025"
            case .ny2026: return "ny-2026"
            }
        }

        static let count: Int = {
            var max: Int = 0
            while let _ = AppIconRows(rawValue: max) { max += 1 }
            return max
        }()
    }

    override func viewDidLoad() {
        self.title = NSLocalizedString("Icon", comment: "Settings")
        super.viewDidLoad()
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        for row in AppIconRows.allCases {
            if let cell = tableView.cellForRow(at: IndexPath(row: row.rawValue, section: 0)) {
                cell.accessoryType = .none
            }
        }

        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .checkmark

            if let icon = AppIconRows(rawValue: indexPath.row)?.description {
                let name = icon == "modern" ? nil : icon

                UIApplication.shared.setAlternateIconName(name) { error in
                    if let error = error {
                        print("Error setting alternate icon \(String(describing: name)): \(error.localizedDescription)")
                    } else {
                        UserDefaultsManagement.appIcon = indexPath.row
                    }
                }
            }
        }

        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let marginguide = cell.contentView.layoutMarginsGuide

        cell.imageView?.translatesAutoresizingMaskIntoConstraints = false
        cell.imageView?.topAnchor.constraint(equalTo: marginguide.topAnchor).isActive = true
        cell.imageView?.leadingAnchor.constraint(equalTo: marginguide.leadingAnchor).isActive = true
        cell.imageView?.heightAnchor.constraint(equalToConstant: 100).isActive = true
        cell.imageView?.widthAnchor.constraint(equalToConstant: 100).isActive = true

        cell.imageView?.layer.borderColor = UIColor.gray.cgColor
        cell.imageView?.layer.borderWidth = 2
        cell.imageView?.layer.backgroundColor = UIColor.white.cgColor

        cell.imageView?.contentMode = .scaleAspectFill
        cell.imageView?.layer.cornerRadius = 20

        if let icon = AppIconRows(rawValue: indexPath.row) {
            let iconName = "AppIcon" + icon.description.capitalizingFirstLetter()

            if let image = UIImage(named: iconName) {
                cell.imageView?.image = image
            }

            cell.textLabel?.text = icon.getName()
        }

        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AppIconRows.count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == UserDefaultsManagement.appIcon {
            cell.accessoryType = .checkmark
        }
    }
}
