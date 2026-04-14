//
//  SFTPViewController.swift
//  FSNotes iOS
//
//  Created for FSNotes iOS SFTP web publishing support.
//

import UIKit
import Shout

class SFTPViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    enum SFTPSection: Int, CaseIterable {
        case server
        case authentication
        case actions

        var title: String {
            switch self {
            case .server: return NSLocalizedString("Server", comment: "SFTP settings")
            case .authentication: return NSLocalizedString("Authentication", comment: "SFTP settings")
            case .actions: return NSLocalizedString("Actions", comment: "SFTP settings")
            }
        }
    }

    // MARK: - Row tags for text fields
    private let tagHost = 100
    private let tagPort = 101
    private let tagRemotePath = 102
    private let tagWebURL = 103
    private let tagUsername = 104
    private let tagPassword = 105
    private let tagPassphrase = 106

    private var privateKeyData: Data? {
        get { return UserDefaultsManagement.sftpAccessData }
        set { UserDefaultsManagement.sftpAccessData = newValue }
    }

    private var publicKeyData: Data? {
        get { return UserDefaultsManagement.sftpPublicKeyData }
        set { UserDefaultsManagement.sftpPublicKeyData = newValue }
    }

    private lazy var documentPickerPrivateKey: UIDocumentPickerViewController = {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .formSheet
        return picker
    }()

    private lazy var documentPickerPublicKey: UIDocumentPickerViewController = {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .formSheet
        return picker
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Web Publishing (SFTP)", comment: "Settings")
        navigationItem.largeTitleDisplayMode = .always

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView.delegate = self
        tableView.dataSource = self
        tableView.keyboardDismissMode = .interactive

        setupKeyboardObservers()
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return SFTPSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch SFTPSection(rawValue: section)! {
        case .server:         return 4  // host, port, remote path, web URL
        case .authentication: return 5  // username, password, private key, public key, passphrase
        case .actions:        return 2  // enable custom server toggle + test button
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SFTPSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch SFTPSection(rawValue: indexPath.section)! {
        case .server:
            return makeTextFieldCell(for: indexPath)
        case .authentication:
            return makeAuthCell(for: indexPath)
        case .actions:
            return makeActionCell(for: indexPath)
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == SFTPSection.authentication.rawValue && indexPath.row == 2 {
            present(documentPickerPrivateKey, animated: true)
        }

        if indexPath.section == SFTPSection.authentication.rawValue && indexPath.row == 3 {
            present(documentPickerPublicKey, animated: true)
        }

        if indexPath.section == SFTPSection.actions.rawValue && indexPath.row == 1 {
            testConnection()
        }
    }

    // MARK: - Cell builders

    private func makeTextFieldCell(for indexPath: IndexPath) -> UITableViewCell {
        var labelText = ""
        var placeholder = ""
        var currentValue = ""
        var tag = 0
        var keyboardType: UIKeyboardType = .default
        let isSecure = false

        switch indexPath.row {
        case 0:
            labelText = NSLocalizedString("Host", comment: "")
            placeholder = "example.com"
            currentValue = UserDefaultsManagement.sftpHost
            tag = tagHost
            keyboardType = .URL
        case 1:
            labelText = NSLocalizedString("Port", comment: "")
            placeholder = "22"
            currentValue = UserDefaultsManagement.sftpPort > 0 ? "\(UserDefaultsManagement.sftpPort)" : ""
            tag = tagPort
            keyboardType = .numberPad
        case 2:
            labelText = NSLocalizedString("Remote Path", comment: "")
            placeholder = "/var/www/notes/"
            currentValue = UserDefaultsManagement.sftpPath ?? ""
            tag = tagRemotePath
        case 3:
            labelText = NSLocalizedString("Web URL", comment: "")
            placeholder = "https://example.com/notes/"
            currentValue = UserDefaultsManagement.sftpWeb ?? ""
            tag = tagWebURL
            keyboardType = .URL
        default:
            break
        }

        return makeLabelTextFieldCell(label: labelText, placeholder: placeholder,
                                      value: currentValue, tag: tag,
                                      keyboardType: keyboardType, isSecure: isSecure)
    }

    private func makeAuthCell(for indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            return makeLabelTextFieldCell(
                label: NSLocalizedString("Username", comment: ""),
                placeholder: "admin",
                value: UserDefaultsManagement.sftpUsername,
                tag: tagUsername
            )
        case 1:
            return makeLabelTextFieldCell(
                label: NSLocalizedString("Password", comment: ""),
                placeholder: NSLocalizedString("(or use private key)", comment: ""),
                value: UserDefaultsManagement.sftpPassword,
                tag: tagPassword,
                isSecure: true
            )
        case 2:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = NSLocalizedString("Private Key", comment: "")
            cell.accessoryType = .disclosureIndicator

            if privateKeyData != nil {
                cell.detailTextLabel?.text = "✓ " + NSLocalizedString("loaded", comment: "")
                let deleteButton = UIButton(type: .system)
                deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
                deleteButton.frame = CGRect(x: 0, y: 0, width: 35, height: 35)
                deleteButton.addTarget(self, action: #selector(deletePrivateKey), for: .touchUpInside)
                cell.accessoryView = deleteButton
            } else {
                cell.detailTextLabel?.text = NSLocalizedString("not set", comment: "")
            }
            return cell

        case 3:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = NSLocalizedString("Public Key", comment: "")
            cell.accessoryType = .disclosureIndicator

            if publicKeyData != nil {
                cell.detailTextLabel?.text = "✓ " + NSLocalizedString("loaded", comment: "")
                let deleteButton = UIButton(type: .system)
                deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
                deleteButton.frame = CGRect(x: 0, y: 0, width: 35, height: 35)
                deleteButton.addTarget(self, action: #selector(deletePublicKey), for: .touchUpInside)
                cell.accessoryView = deleteButton
            } else {
                cell.detailTextLabel?.text = NSLocalizedString("not set", comment: "")
            }
            return cell

        case 4:
            return makeLabelTextFieldCell(
                label: NSLocalizedString("Passphrase", comment: ""),
                placeholder: NSLocalizedString("(optional)", comment: ""),
                value: UserDefaultsManagement.sftpPassphrase,
                tag: tagPassphrase,
                isSecure: true
            )

        default:
            return UITableViewCell()
        }
    }

    private func makeActionCell(for indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = NSLocalizedString("Use Custom SFTP Server", comment: "")
            let toggle = UISwitch()
            toggle.isOn = UserDefaultsManagement.customWebServer
            toggle.addTarget(self, action: #selector(customServerToggleChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            return cell

        case 1:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = NSLocalizedString("Test Connection", comment: "")
            cell.textLabel?.textColor = .systemBlue
            cell.textLabel?.textAlignment = .center
            return cell

        default:
            return UITableViewCell()
        }
    }

    // MARK: - Text field helpers

    /// Builds a cell with a fixed-width label on the left and an editable text field on the right.
    private func makeLabelTextFieldCell(label: String,
                                        placeholder: String,
                                        value: String,
                                        tag: Int,
                                        keyboardType: UIKeyboardType = .default,
                                        isSecure: Bool = false) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = label
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = placeholder
        textField.text = value
        textField.tag = tag
        textField.textAlignment = .right
        textField.textColor = UIColor.secondaryLabel
        textField.keyboardType = keyboardType
        textField.isSecureTextEntry = isSecure
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        let cv = cell.contentView
        cv.addSubview(titleLabel)
        cv.addSubview(textField)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: cv.centerYAnchor),

            textField.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: cv.topAnchor),
            textField.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
        ])

        return cell
    }

    // MARK: - Actions

    @objc private func textFieldDidChange(_ sender: UITextField) {
        let text = sender.text ?? ""
        switch sender.tag {
        case tagHost:        UserDefaultsManagement.sftpHost = text
        case tagPort:        UserDefaultsManagement.sftpPort = Int32(text) ?? 22
        case tagRemotePath:  UserDefaultsManagement.sftpPath = text
        case tagWebURL:      UserDefaultsManagement.sftpWeb = text
        case tagUsername:    UserDefaultsManagement.sftpUsername = text
        case tagPassword:    UserDefaultsManagement.sftpPassword = text
        case tagPassphrase:  UserDefaultsManagement.sftpPassphrase = text
        default: break
        }
    }

    @objc private func customServerToggleChanged(_ sender: UISwitch) {
        UserDefaultsManagement.customWebServer = sender.isOn
    }

    @objc private func deletePrivateKey() {
        privateKeyData = nil
        tableView.reloadSections(IndexSet(integer: SFTPSection.authentication.rawValue), with: .automatic)
    }

    @objc private func deletePublicKey() {
        publicKeyData = nil
        tableView.reloadSections(IndexSet(integer: SFTPSection.authentication.rawValue), with: .automatic)
    }

    private func testConnection() {
        let host = UserDefaultsManagement.sftpHost
        guard !host.isEmpty else {
            showAlert(title: NSLocalizedString("Missing Host", comment: ""),
                      message: NSLocalizedString("Please enter a host address.", comment: ""))
            return
        }

        let hud = UIAlertController(title: NSLocalizedString("Testing…", comment: ""), message: nil, preferredStyle: .alert)
        present(hud, animated: true)

        DispatchQueue.global().async {
            do {
                guard let ssh = try SFTPUploader.makeSSH() else {
                    DispatchQueue.main.async {
                        hud.dismiss(animated: true) {
                            self.showAlert(title: NSLocalizedString("Connection Failed", comment: ""),
                                          message: NSLocalizedString("Could not authenticate. Check credentials.", comment: ""))
                        }
                    }
                    return
                }
                _ = try ssh.capture("echo ok")

                DispatchQueue.main.async {
                    hud.dismiss(animated: true) {
                        self.showAlert(title: NSLocalizedString("Connection Successful", comment: ""),
                                      message: NSLocalizedString("Successfully connected to the server.", comment: ""))
                    }
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                DispatchQueue.main.async {
                    hud.dismiss(animated: true) {
                        self.showAlert(title: NSLocalizedString("Connection Failed", comment: ""),
                                       message: message)
                    }
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Keyboard

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        UIView.animate(withDuration: 0.3) {
            self.tableView.contentInset.bottom = frame.height - self.view.safeAreaInsets.bottom
            self.tableView.verticalScrollIndicatorInsets.bottom = frame.height - self.view.safeAreaInsets.bottom
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.3) {
            self.tableView.contentInset.bottom = 0
            self.tableView.verticalScrollIndicatorInsets.bottom = 0
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UIDocumentPickerDelegate

extension SFTPViewController: UIDocumentPickerDelegate, UINavigationControllerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
        if controller === documentPickerPublicKey {
            publicKeyData = data
        } else {
            privateKeyData = data
        }
        tableView.reloadSections(IndexSet(integer: SFTPSection.authentication.rawValue), with: .automatic)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
}
