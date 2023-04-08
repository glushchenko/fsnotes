//
//  AppIconViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Hlushchenko on 07.04.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit
import NightNight

class AppIconViewController: UITableViewController {
    enum AppIconRows: Int, CaseIterable {
        case kmstrr
        case dylanseeger

        public func getName() -> String {
            switch self {
            case .kmstrr:
                return "Classic"
            case .dylanseeger:
                return "Dylan Seeger"
            }
        }

        var description : String {
            switch self {
            case .kmstrr: return "kmstrr"
            case .dylanseeger: return "dylanseeger"
            }
        }

        static let count: Int = {
            var max: Int = 0
            while let _ = AppIconRows(rawValue: max) { max += 1 }
            return max
        }()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Icons", comment: "Settings")
    }

    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        self.title = NSLocalizedString("App Icon", comment: "Settings")
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
                UIApplication.shared.setAlternateIconName(icon + "Icon") { error in
                    if let error = error {
                        print("Error setting alternate icon \(icon): \(error.localizedDescription)")
                    }
                }
            }

            UserDefaultsManagement.appIcon = indexPath.row
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
            if let image = UIImage(named: "app-icon-\(icon.description)") {
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
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

        if indexPath.row == UserDefaultsManagement.appIcon {
            cell.accessoryType = .checkmark
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            if NightNight.theme == .night {
                headerView.textLabel?.textColor = UIColor(red: 0.48, green: 0.48, blue: 0.51, alpha: 1.00)
            } else {
                headerView.textLabel?.textColor = UIColor(red: 0.47, green: 0.47, blue: 0.48, alpha: 1.00)
            }
        }
    }
}
