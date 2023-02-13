//
//  GitViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Hlushchenko on 05.02.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit
import NightNight
import CoreServices

class GitViewController: UITableViewController {
    private var sections = [
        NSLocalizedString("Credentials", comment: "Settings"),
        NSLocalizedString("Origin", comment: "Settings"),
        NSLocalizedString("Repositores", comment: "Settings"),
    ]

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }

    private var rows = [
        [
            NSLocalizedString("Private key", comment: ""),
            NSLocalizedString("Passphrase", comment: ""),
        ], [
            NSLocalizedString("", comment: ""),
            NSLocalizedString("", comment: ""),
        ]
    ]

    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        self.title = NSLocalizedString("Git", comment: "Settings")
        super.viewDidLoad()
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row == 0 {
            changePrivateKey(tableView: tableView, indexPath: indexPath)
        }

        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Passphrase and origin
        if indexPath.section == 0 && indexPath.row == 1 || (
            indexPath.section == 1 && indexPath.row == 0
        ) {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = rows[indexPath.section][indexPath.row]
        
            let textField = UITextField()
            
            // Passphrase
            if indexPath.section == 0 && indexPath.row == 1 {
                textField.isSecureTextEntry = true
                textField.addTarget(self, action: #selector(passphraseDidChange), for: .editingChanged)
                textField.placeholder = "(optional)"
                textField.text = UserDefaultsManagement.gitPassphrase
            }
            
            // Origin
            if indexPath.section == 1 && indexPath.row == 0 {
                textField.addTarget(self, action: #selector(originDidChange), for: .editingChanged)
                textField.placeholder = "git@github.com:username/example.git"
                
                if let origin = UserDefaultsManagement.gitOrigin {
                    textField.text = origin
                }
            }
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.textAlignment = .right
            
            cell.contentView.addSubview(textField)
            cell.addConstraint(NSLayoutConstraint(item: textField, attribute: .leading, relatedBy: .equal, toItem: cell.textLabel, attribute: .trailing, multiplier: 1, constant: 8))
            cell.addConstraint(NSLayoutConstraint(item: textField, attribute: .top, relatedBy: .equal, toItem: cell.contentView, attribute: .top, multiplier: 1, constant: 8))
            cell.addConstraint(NSLayoutConstraint(item: textField, attribute: .bottom, relatedBy: .equal, toItem: cell.contentView, attribute: .bottom, multiplier: 1, constant: -8))
            cell.addConstraint(NSLayoutConstraint(item: textField, attribute: .trailing, relatedBy: .equal, toItem: cell.contentView, attribute: .trailing, multiplier: 1, constant: -8))
            
            return cell
        }
        
        // Clone button
        if indexPath.section == 1 && indexPath.row == 1 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            let button = UIButton()
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: button.titleLabel!.font.pointSize)
            button.setTitle("Clone", for: .normal)
            button.setTitleColor(.red, for: .normal)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(clonePressed), for: .touchUpInside)
            
            cell.contentView.addSubview(button)
            cell.addConstraint(NSLayoutConstraint(item: button, attribute: .leading, relatedBy: .equal, toItem: cell.contentView, attribute: .leading, multiplier: 1, constant: 8))
            cell.addConstraint(NSLayoutConstraint(item: button, attribute: .top, relatedBy: .equal, toItem: cell.contentView, attribute: .top, multiplier: 1, constant: 8))
            cell.addConstraint(NSLayoutConstraint(item: button, attribute: .bottom, relatedBy: .equal, toItem: cell.contentView, attribute: .bottom, multiplier: 1, constant: -8))
            cell.addConstraint(NSLayoutConstraint(item: button, attribute: .trailing, relatedBy: .equal, toItem: cell.contentView, attribute: .trailing, multiplier: 1, constant: -8))
            
            return cell
        }
        
        // Repositories list
        if indexPath.section == 2 {
            let names = getRepoNames()
            
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = names![indexPath.row]
            return cell
        }
        
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = rows[indexPath.section][indexPath.row]
        
        // Private key
        if indexPath.section == 0 && indexPath.row == 0 {
            if UserDefaultsManagement.gitPrivateKeyData != nil {
                cell.detailTextLabel?.text = "id_rsa"
                
                let accessoryButton = UIButton(type: .custom)
                accessoryButton.addTarget(self, action: #selector(deletePrivateKey(sender:)), for: .touchUpInside)
                accessoryButton.setImage(UIImage(named: "trash"), for: .normal)
                accessoryButton.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
                accessoryButton.contentMode = .scaleAspectFit
                cell.accessoryView = accessoryButton
            }
        }
        
        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 2 {
            let names = getRepoNames()
            return names?.count ?? 0
        }
        
        return rows[section].count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 2 {
            return true
        }
        
        return false
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let names = getRepoNames()
            let folderName = names![indexPath.row]
            
            let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            guard let repoURL = documentDir?
                .appendingPathComponent("Repositories")
                .appendingPathComponent(folderName) else { return }
            
            try? FileManager.default.removeItem(at: repoURL)
            tableView.reloadData()
        }
    }

    private func changePrivateKey(tableView: UITableView, indexPath: IndexPath) {
        let types: [String] = ["public.data"]
        let documentPicker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    @objc func deletePrivateKey(sender: UIButton) {
        UserDefaultsManagement.gitPrivateKeyData = nil
        
        if let rsaURL = GitViewController.getRsaUrl() {
            try? FileManager.default.removeItem(at: rsaURL)
        }
        
        guard let cell = sender.superview as? UITableViewCell,
            let tableView = cell.superview as? UITableView,
            let indexPath = tableView.indexPath(for: cell) else { return }
        
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    @objc func passphraseDidChange(sender: UITextField) {
        guard let text = sender.text else { return }
        
        UserDefaultsManagement.gitPassphrase = text
    }
    
    @objc func originDidChange(sender: UITextField) {
        guard let text = sender.text else { return }
        
        UserDefaultsManagement.gitOrigin = text
    }
    
    @objc func clonePressed(sender: UIButton) {
        guard let project = Storage.shared().getDefault() else { return }
        
        UIApplication.getVC().gitQueue.cancelAllOperations()
        
        project.gitOrigin = UserDefaultsManagement.gitOrigin
        project.saveSettings()
        
        do {
            try project.pull()
                
            if let repo = try project.getRepository(), let local = project.getLocalBranch(repository: repo) {
                try repo.head().forceCheckout(branch: local)
            }
            return
        } catch GitError.unknownError(let errorMessage, _, let desc){
            let message = errorMessage + " – " + desc
            errorAlert(title: "Git clone/pull error", message: message)
        } catch GitError.notFound(let ref) {
            print(ref)
            
            // Empty repository – commit and push
            if ref == "refs/heads/master" {
                try? project.commit()
                try? project.push()
            }
        } catch {
            let message = error.localizedDescription
            errorAlert(title: "Git error", message: message)
        }
    }
    
    public func errorAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .cancel) { (_) in }
        alertController.addAction(okAction)

        self.present(alertController, animated: true, completion: nil)
    }
    
    public static func installGitKey() {
        if let keyData = UserDefaultsManagement.gitPrivateKeyData, let rsaURL = getRsaUrl() {
            do {
                try keyData.write(to: rsaURL)
            } catch {
                print(error)
            }
        }
    }
    
    public static func getRsaUrl() -> URL? {
        let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let rsaKey = documentDir?.appendingPathComponent("id_rsa", isDirectory: false) {
            return rsaKey
        }
        return nil
    }
    
    public func getRepoNames() -> [String]? {
        let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let repoURL = documentDir?.appendingPathComponent("Repositories") else { return nil }
        
        guard var names = try? FileManager.default.contentsOfDirectory(atPath: repoURL.path) else { return nil }
        names.removeAll(where: { $0 == "tmp" })
        
        return names
    }
}

extension GitViewController: UIDocumentPickerDelegate, UINavigationControllerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        
        UserDefaultsManagement.gitPrivateKeyData = data
        GitViewController.installGitKey()
        
        tableView.reloadData()
    }

     func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
