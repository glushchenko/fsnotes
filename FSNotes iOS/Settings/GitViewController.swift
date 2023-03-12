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
    enum ButtonAction: Int, CaseIterable {
        case initCommit
        case clonePush
        case commit
        case pull
        case push

        var title: String {
            switch self {
            case .initCommit: return "Init/commit"
            case .clonePush: return "Clone/push"
            case .pull: return "Pull"
            case .commit: return "Add/commit"
            case .push: return "Push"
            }
        }
    }
    
    enum GitSection: Int, CaseIterable {
        case credentials
        case origin
        case logs

        var title: String {
            switch self {
            case .credentials: return "Credentials"
            case .origin: return "Origin"
            case .logs: return "Status"
            }
        }
    }

    private var hasActiveGit: Bool = false
    private var progress: GitProgress?
    private var project: Project?

    public var activity: UIActivityIndicatorView?
    public var leftButton: UIButton?
    public var rightButton: UIButton?
    public var logTextField: UITextField?

    public func setProject(_ project: Project) {
        self.project = project
    }

    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))
        self.title = NSLocalizedString("Git", comment: "Settings")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true

        initNavigationBackground()

        DispatchQueue.main.async {
            self.updateButtons(isActive: self.hasActiveGit)

            if let status = self.project?.gitStatus {
                self.logTextField?.text = status
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    override func viewDidLayoutSubviews() {
        if let rect = self.navigationController?.navigationBar.frame {
            let y = rect.size.height
            self.tableView.contentInset = UIEdgeInsets( top: y, left: 0, bottom: 0, right: 0)
        }
    }
        
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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
        guard let project = project else { return UITableViewCell() }
        
        // Passphrase and origin
        if indexPath.section == GitSection.credentials.rawValue && indexPath.row == 1 || (
            indexPath.section == GitSection.origin.rawValue && indexPath.row == 0 ||
            indexPath.section == GitSection.logs.rawValue && indexPath.row == 0
        ) {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            
            if indexPath.section == 0 {
                cell.textLabel?.text = indexPath.row == 0
                    ? NSLocalizedString("Private key", comment: "")
                    : NSLocalizedString("Passphrase", comment: "")
            }
        
            let textField = UITextField()
            
            // Passphrase
            if indexPath.section == GitSection.credentials.rawValue && indexPath.row == 1 {
                textField.isSecureTextEntry = true
                textField.addTarget(self, action: #selector(passphraseDidChange), for: .editingChanged)
                textField.placeholder = "(optional)"
                textField.text = project.settings.gitPrivateKeyPassphrase
            }
            
            // Origin
            if indexPath.section == GitSection.origin.rawValue && indexPath.row == 0 {
                textField.addTarget(self, action: #selector(originDidChange), for: .editingChanged)
                textField.placeholder = "git@github.com:username/example.git"
                textField.text = project.settings.gitOrigin ?? ""
            }
            
            // Logs
            if indexPath.section == GitSection.logs.rawValue && indexPath.row == 0 {
                textField.placeholder = "No data"
                textField.isEnabled = false

                logTextField = textField
                progress = GitProgress(statusTextField: textField, project: project)
                
                // Global instance
                AppDelegate.gitProgress = progress
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "gitTableViewCell", for: indexPath) as! GitTableViewCell
            cell.selectionStyle = .none
            cell.cloneButton.addTarget(self, action: #selector(repoPressed), for: .touchUpInside)
            cell.removeButton.addTarget(self, action: #selector(removePressed), for: .touchUpInside)
            
            leftButton = cell.cloneButton
            rightButton = cell.removeButton
            activity = cell.activity
            
            activity?.isHidden = true
            activity?.startAnimating()
            
            return cell
        }
                
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        
        // Private key
        if indexPath.section == GitSection.credentials.rawValue && indexPath.row == 0 {
            if project.settings.gitPrivateKey != nil {
                cell.detailTextLabel?.text = NSLocalizedString("Found one private key 👍", comment: "")
                
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
        if section == 0 || section == 1 {
            return 2
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
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
        guard let project = project else { return }
        
        project.settings.gitPrivateKey = nil
        project.saveSettings()
        
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
        guard let project = project else { return }
        
        project.settings.gitPrivateKeyPassphrase = text
        project.saveSettings()
    }
    
    @objc func originDidChange(sender: UITextField) {
        guard let project = project, let origin = sender.text else { return }
    
        project.settings.setOrigin(origin)
        project.saveSettings()

        updateButtons()
    }
    
    @objc func removePressed(sender: UIButton) {
        guard let project = project else { return }

        project.removeRepository()
        rightButton?.isEnabled = false

        progress?.log(message: "git repository removed")
        updateButtons()
    }
    
    @objc func repoPressed(sender: UIButton) {
        let action = getButtonAction()
        updateButtons(isActive: true)
        
        UIApplication.shared.isIdleTimerDisabled = true
        UIApplication.getVC().gitQueue.addOperation({
            defer {
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                    UIApplication.getVC().scheduledGitPull()

                    self.updateButtons(isActive: false)
                }
            }
            
            switch action {
            case .initCommit:
                self.initRepository()
                self.commit()
                break
            case .clonePush:
                self.clonePush()
                break
            case .commit:
                self.commit()
                break
            case .pull:
                self.pull()
                break
            case .push:
                self.push()
                break
            }
        })
    }
    
    public func initRepository() {
        guard let project = project else { return }
        
        do {
            _ = try project.initBareRepository()
        } catch {
            DispatchQueue.main.async {
                let message = error.localizedDescription
                self.errorAlert(title: "git init error", message: message)
            }
        }
    }
    
    public func pull() {
        guard let project = project else { return }
        
        do {
            try project.pull()
            progress?.log(message: "\(project.label) – successful git pull 👌")
        } catch {
            DispatchQueue.main.async {
                let message = error.localizedDescription
                self.errorAlert(title: "git init error", message: message)
            }
        }
    }
    
    public func clonePush() {
        guard let project = project else { return }
                
        do {
            if let repo = try project.cloneRepository(),
               let local = project.getLocalBranch(repository: repo)
            {
                try repo.head().forceCheckout(branch: local)
                project.cacheHistory(progress: progress)
                
                DispatchQueue.main.async {
                    // Reload all files and tables
                    UIApplication.getVC().reloadDatabase()
                }
            } else {
                commit()
                push()
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
                self.commit()
                self.push()
                
                progress?.log(message: "Successful git push 👌")
            }
        } catch {
            DispatchQueue.main.async {
                let message = error.localizedDescription
                self.errorAlert(title: "git error", message: message)
            }
        }
    }
        
    public func push() {
        guard let project = project else { return }
        
        do {
            try project.push()
        } catch {
            let message = error.localizedDescription
            self.errorAlert(title: "git clone/pull error", message: message)
        }
    }
    
    public func commit() {
        guard let project = project else { return }
        
        do {
            try project.commit(message: nil, progress: progress)
        } catch {
            let message = error.localizedDescription
            self.errorAlert(title: "git clone/pull error", message: message)
        }
    }
    
    public func errorAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let okAction = UIAlertAction(title: "OK", style: .cancel) { (_) in }
            alertController.addAction(okAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
        
    public static func getRsaUrl() -> URL? {
        let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let rsaKey = documentDir?.appendingPathComponent("id_rsa", isDirectory: false) {
            return rsaKey
        }
        return nil
    }
    
    public func updateButtons(isActive: Bool? = nil) {
        guard let project = project else { return }

        if let isActive = isActive {
            hasActiveGit = isActive
            leftButton?.isEnabled = !isActive
            activity?.isHidden = !isActive
        }

        rightButton?.isEnabled = project.hasRepository()

        let state = getButtonAction()
        leftButton?.setTitle(state.title, for: .normal)
    }
    
    public func getButtonAction() -> ButtonAction {
        guard let project = project else { return .initCommit }
        
        if project.hasRepository() {
            if project.settings.gitOrigin != nil {
                return .pull
            } else {
                return .commit
            }
        } else {
            if project.settings.gitOrigin != nil {
                return .clonePush
            } else {
                return .initCommit
            }
        }
    }
}

extension GitViewController: UIDocumentPickerDelegate, UINavigationControllerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        guard let project = project else { return }
        
        project.settings.gitPrivateKey = data
        project.saveSettings()
        
        tableView.reloadData()
    }

     func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
