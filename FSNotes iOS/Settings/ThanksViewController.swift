//
//  ThanksViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 06.03.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class ThanksViewController: UITableViewController {
    private var rows = [
        "Radio-T",
        "Matt Septhon",
        "Dylan Seeger (Icon design)"
    ]

    private var urls = [
        "https://radio-t.com",
        "https://www.gingerbeardman.com",
        "https://lovably.com"
    ]

    override func viewDidLoad() {
        initNavigationBackground()

        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))
        self.title = NSLocalizedString("Thanks to", comment: "Settings")

        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let url = URL(string: urls[indexPath.row]) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }

        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = rows[indexPath.row]

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        return cell
    }

    @objc func cancel() {
        navigationController?.popViewController(animated: true)
    }
}


