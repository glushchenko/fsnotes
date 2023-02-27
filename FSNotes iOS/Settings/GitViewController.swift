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
    
    enum GitSection: Int, CaseIterable {
        case credentials
        case origin
        case logs
        case repositories

        var title: String {
            switch self {
            case .credentials: return "Credentials"
            case .origin: return "Origin"
            case .logs: return "Status"
            case .repositories: return "Repositories"
            }
        }
    }
    
    private var rows = [
        [
            NSLocalizedString("Private key", comment: ""),
            NSLocalizedString("Passphrase", comment: ""),
        ], [
            NSLocalizedString("", comment: ""),
            NSLocalizedString("", comment: ""),
        ], [
            "",
        ]
    ]
    
    // Clone
    public var button = UIButton()
    
    public static var logTextField: UITextField?
    
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        self.title = NSLocalizedString("Git", comment: "Settings")
        super.viewDidLoad()
        
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: button.titleLabel!.font.pointSize)
        button.setTitle("Clone", for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(clonePressed), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true
        
        DispatchQueue.main.async {
            GitViewController.logTextField?.text = Progress.bufferedMessage
        }
        
        if UIApplication.getVC().isActiveClone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.button.loadingIndicator(show: true)
            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = false
        
        self.button.loadingIndicator(show: false)
    }
    
    public func repositoriesNames() -> [String]? {
        var names = [String]()
        
        if !UserDefaultsManagement.iCloudDrive {
            let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            if let dotGit = documentDir?.appendingPathComponent(".git", isDirectory: true) {
                if FileManager.default.fileExists(atPath: dotGit.path, isDirectory: nil) {
                    names.append("Documents.git")
                }
            }
        } else {
            let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            guard let repoURL = documentDir?.appendingPathComponent("Repositories") else { return nil }
            
            if let result = try? FileManager.default.contentsOfDirectory(atPath: repoURL.path) {
                names = result
            }
            
            names.removeAll(where: { $0 == "tmp" })
        }
        
        return names
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == GitSection.repositories.rawValue && repositoriesNames()?.count == 0 {
            return nil
        }
        
        return GitSection(rawValue: section)?.title
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == GitSection.credentials.rawValue && indexPath.row == 0 {
            changePrivateKey(tableView: tableView, indexPath: indexPath)
        }

        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Passphrase and origin
        if indexPath.section == GitSection.credentials.rawValue && indexPath.row == 1 || (
            indexPath.section == GitSection.origin.rawValue && indexPath.row == 0 ||
            indexPath.section == GitSection.logs.rawValue && indexPath.row == 0
        ) {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = rows[indexPath.section][indexPath.row]
        
            let textField = UITextField()
            
            // Passphrase
            if indexPath.section == GitSection.credentials.rawValue && indexPath.row == 1 {
                textField.isSecureTextEntry = true
                textField.addTarget(self, action: #selector(passphraseDidChange), for: .editingChanged)
                textField.placeholder = "(optional)"
                textField.text = UserDefaultsManagement.gitPassphrase
            }
            
            // Origin
            if indexPath.section == GitSection.origin.rawValue && indexPath.row == 0 {
                textField.addTarget(self, action: #selector(originDidChange), for: .editingChanged)
                textField.placeholder = "git@github.com:username/example.git"
                
                if let origin = UserDefaultsManagement.gitOrigin {
                    textField.text = origin
                }
            }
            
            // Logs
            if indexPath.section == GitSection.logs.rawValue && indexPath.row == 0 {
                textField.placeholder = "No data"
                textField.isEnabled = false
                
                GitViewController.logTextField = textField
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
        if indexPath.section == GitSection.origin.rawValue && indexPath.row == 1 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.contentView.addSubview(button)
            cell.addConstraint(NSLayoutConstraint(item: button, attribute: .leading, relatedBy: .equal, toItem: cell.contentView, attribute: .leading, multiplier: 1, constant: 8))
            cell.addConstraint(NSLayoutConstraint(item: button, attribute: .top, relatedBy: .equal, toItem: cell.contentView, attribute: .top, multiplier: 1, constant: 8))
            cell.addConstraint(NSLayoutConstraint(item: button, attribute: .bottom, relatedBy: .equal, toItem: cell.contentView, attribute: .bottom, multiplier: 1, constant: -8))
            cell.addConstraint(NSLayoutConstraint(item: button, attribute: .trailing, relatedBy: .equal, toItem: cell.contentView, attribute: .trailing, multiplier: 1, constant: -8))
            
            return cell
        }
        
        // Repositories list
        if indexPath.section == GitSection.repositories.rawValue {
            let names = repositoriesNames()
            
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = names![indexPath.row]
            return cell
        }
        
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = rows[indexPath.section][indexPath.row]
        
        // Private key
        if indexPath.section == GitSection.credentials.rawValue && indexPath.row == 0 {
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
        return GitSection.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == GitSection.repositories.rawValue {
            return repositoriesNames()?.count ?? 0
        }
        
        return rows[section].count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == GitSection.repositories.rawValue {
            return true
        }
        
        return false
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            var repoURL: URL?
            let folderName = repositoriesNames()![indexPath.row]

            if UserDefaultsManagement.iCloudDrive {
                let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                repoURL = documentDir?
                    .appendingPathComponent("Repositories")
                    .appendingPathComponent(folderName)
            } else {
                let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                repoURL = documentDir?.appendingPathComponent(".git", isDirectory: true)
            }
            
            if let repoURL = repoURL {
                try? FileManager.default.removeItem(at: repoURL)
            }

            AppDelegate.gitProgress.log(message: "git repository removed")
            
            UIApplication.getVC().stopGitPull()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                tableView.reloadSections([GitSection.repositories.rawValue], with: .fade)
            })
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
        
        Storage.shared().updateDefaultOrigin()
    }
    
    @objc func clonePressed(sender: UIButton) {
        button.loadingIndicator(show: true)
        button.isEnabled = false
        
        guard let project = Storage.shared().getDefault() else { return }
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        UIApplication.getVC().isActiveClone = true
        UIApplication.getVC().stopGitPull()
        UIApplication.getVC().gitQueue.addOperation({
            defer {
                DispatchQueue.main.async {
                    self.button.isEnabled = true
                    
                    UIApplication.shared.isIdleTimerDisabled = false
                    
                    UIApplication.getVC().scheduledGitPull()
                    UIApplication.getVC().isActiveClone = false
                    
                    self.button.loadingIndicator(show: false)
                    self.tableView.reloadData()
                }
            }
            
            do {
                try? FileManager.default.removeItem(at: project.getRepositoryUrl()) 
                                    
                self.reloadRepositoriesSection()
                
                if let repo = try project.initRepository(),
                    let local = project.getLocalBranch(repository: repo)
                {
                    try repo.head().forceCheckout(branch: local)
                    
                    DispatchQueue.main.async {
                        // Reload all files and tables
                        UIApplication.getVC().reloadDatabase()
                        UIApplication.getVC().gitPull = true
                    }
                }

                return
            } catch GitError.unknownError(let errorMessage, _, let desc) {
                DispatchQueue.main.async {
                    let message = errorMessage + " – " + desc
                    self.errorAlert(title: "git clone/pull error", message: message)
                }
            } catch GitError.notFound(let ref) {
                // Empty repository – commit and push
                if ref == "refs/heads/master" {
                    let completionPreAdd = { AppDelegate.gitProgress.log(message: "Empty repo, git add -A") }
                    let completionPreCommit = { AppDelegate.gitProgress.log(message: "git commit") }
                    
                    try? project.commit(completionPreAdd: completionPreAdd, completionPreCommit: completionPreCommit)
                    try? project.push()
                    
                    DispatchQueue.main.async {
                        UIApplication.getVC().gitPull = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    let message = error.localizedDescription
                    self.errorAlert(title: "Git error", message: message)
                }
            }
        })
    }
    
    public func errorAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let okAction = UIAlertAction(title: "OK", style: .cancel) { (_) in }
            alertController.addAction(okAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
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
    
    private func reloadRepositoriesSection() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
            self.tableView?.reloadSections([GitSection.repositories.rawValue], with: .fade)
        })
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

extension UIButton {
    func loadingIndicator(show: Bool) {
        let tag = 9876
        if show {
            let indicator = UIActivityIndicatorView()
            let buttonHeight = self.bounds.size.height
            let buttonWidth = self.bounds.size.width
            indicator.center = CGPointMake(buttonWidth/2 + 50, buttonHeight/2)
            indicator.tag = tag
            self.addSubview(indicator)
            indicator.startAnimating()
        } else {
            if let indicator = self.viewWithTag(tag) as? UIActivityIndicatorView {
                indicator.stopAnimating()
                indicator.removeFromSuperview()
            }
        }
    }
}
