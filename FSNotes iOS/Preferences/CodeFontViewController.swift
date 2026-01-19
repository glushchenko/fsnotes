//
//  CodeFontViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 3/16/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class CodeFontViewController: UITableViewController {
    private var fontFamilyNames = [
        "Source Code Pro",
        "Menlo",
        "Courier",
    ]

    override func viewDidLoad() {
        title = NSLocalizedString("Font Family", comment: "Settings")

        super.viewDidLoad()
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if fontFamilyNames[indexPath.row] == UserDefaultsManagement.codeFont.familyName {
            cell.accessoryType = .checkmark
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath), let label = cell.textLabel, let fontFamily = label.text {
            let fontSize = UserDefaultsManagement.fontSize

            if indexPath.row == 0 {
                UserDefaultsManagement.codeFontName = "Source Code Pro"
            } else if let customFont = UIFont(name: fontFamily, size: CGFloat(fontSize)) {
                UserDefaultsManagement.codeFont = customFont
            }

            MPreviewView.template = nil

            UIApplication.getVC().notesTable.reloadData()

            self.navigationController?.popViewController(animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = fontFamilyNames[indexPath.row]
        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fontFamilyNames.count
    }
}

