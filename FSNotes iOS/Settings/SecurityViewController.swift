//
//  SecurityViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Hlushchenko on 08.04.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit

class SecurityViewController: UITableViewController {

    lazy var saveButton: UIButton = {
        let button : UIButton = UIButton(type: UIButton.ButtonType.custom) as UIButton
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(saveButtonClicked), for: .touchUpInside)
        button.setTitle(NSLocalizedString("Save", comment: ""), for: UIControl.State.normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 25, bottom: 10, right: 25)
       return button
    }()

    var passwordTextField: UITextField?
    var verifyPasswordTextField: UITextField?

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Master", comment: "Settings")
    }

    override func viewDidLoad() {
        self.title = NSLocalizedString("Security", comment: "Settings")
        super.viewDidLoad()
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let textField = UITextField()

        var password = String()

        do {
            let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")
            password = try item.readPassword()
        } catch {
            print(error)
        }

        textField.text = password

        if indexPath.row == 0 {
            cell.textLabel?.text = NSLocalizedString("Password", comment: "")
            textField.placeholder = "Required"
            passwordTextField = textField
        }

        if indexPath.row == 1 {
            cell.textLabel?.text = NSLocalizedString("Verify Password", comment: "")
            textField.placeholder = "Required"
            verifyPasswordTextField = textField
        }

        if indexPath.row == 2 {
            let cell: UITableViewCell = UITableViewCell()

            cell.selectionStyle = .none
            cell.contentView.addSubview(saveButton)

            saveButton.translatesAutoresizingMaskIntoConstraints = false
            saveButton.centerXAnchor.constraint(equalTo: cell.centerXAnchor).isActive = true
            saveButton.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true

            return cell
        }

        textField.isSecureTextEntry = true

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textAlignment = .right

        cell.contentView.addSubview(textField)
        cell.addConstraint(NSLayoutConstraint(item: textField, attribute: .leading, relatedBy: .equal, toItem: cell.textLabel, attribute: .trailing, multiplier: 1, constant: 8))
        cell.addConstraint(NSLayoutConstraint(item: textField, attribute: .top, relatedBy: .equal, toItem: cell.contentView, attribute: .top, multiplier: 1, constant: 8))
        cell.addConstraint(NSLayoutConstraint(item: textField, attribute: .bottom, relatedBy: .equal, toItem: cell.contentView, attribute: .bottom, multiplier: 1, constant: -8))
        cell.addConstraint(NSLayoutConstraint(item: textField, attribute: .trailing, relatedBy: .equal, toItem: cell.contentView, attribute: .trailing, multiplier: 1, constant: -8))

        return cell
    }

    @objc func saveButtonClicked(sender: UIButton) {
        guard let passwordTextField = passwordTextField,
              let verifyPasswordTextField = verifyPasswordTextField,
              let text = passwordTextField.text else { return }

        let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")

        if text.count > 0, text == verifyPasswordTextField.text {
            do {
                try item.savePassword(text)
            } catch {
                print("Master password saving error: \(error)")
            }

            let title = NSLocalizedString("Password has been successfully changed", comment: "")
            let message = NSLocalizedString("Tip: To use old notes, you must decrypt them separately with the old key and encrypt them again.", comment: "")

            let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            present(alert, animated: true, completion: nil)

            return
        }

        let title = NSLocalizedString("Please try again", comment: "")
        let message = NSLocalizedString("Wrong repeated password", comment: "")
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
