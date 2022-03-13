//
//  CodeThemeViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 3/16/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class CodeThemeViewController: UITableViewController {
    private var themeNames = [
        "github",
        "solarized-light",
        "solarized-dark",
        "vs",
        "atom-one-light",
        "atom-one-dark",
        "monokai-sublime",
        "xcode",
        "zenburn",
        "tomorrow",
        "agate",
    ]

    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        title = NSLocalizedString("Code Theme", comment: "Settings")

        super.viewDidLoad()
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

        //if UserDefaultsManagement.codeFontName == nil && indexPath.row == 0 {
        //    cell.accessoryType = .checkmark
        //}

        if themeNames[indexPath.row] == UserDefaultsManagement.codeTheme {
            cell.accessoryType = .checkmark
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath), let label = cell.textLabel, let theme = label.text {
            UserDefaultsManagement.codeTheme = theme

            NotesTextProcessor.hl = nil
            MPreviewView.template = nil

            UIApplication.getVC().notesTable.reloadData()

            self.navigationController?.popViewController(animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()

        cell.textLabel?.text = themeNames[indexPath.row]

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return themeNames.count
    }
}

