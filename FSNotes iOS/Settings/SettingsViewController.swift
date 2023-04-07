//
//  SettingsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight
import StoreKit
import CoreServices

class SettingsViewController: UITableViewController, UIDocumentPickerDelegate {

    var sections = [
        NSLocalizedString("General", comment: "Settings"),
        NSLocalizedString("Storage", comment: "Settings"),
        NSLocalizedString("FSNotes", comment: "Settings")
    ]

    var rows = [
        [
            NSLocalizedString("File format", comment: "Settings"),
            NSLocalizedString("Editor", comment: "Settings"),
            NSLocalizedString("Night Mode", comment: "Settings"),
            NSLocalizedString("Git", comment: "Settings"),
            NSLocalizedString("App Icon", comment: "Settings"),
            NSLocalizedString("Advanced", comment: "Settings"),
        ], [
            NSLocalizedString("iCloud Drive", comment: "Settings"),
            NSLocalizedString("Add External Folder", comment: "Settings"),
            NSLocalizedString("Projects", comment: "Settings"),
            NSLocalizedString("Import notes", comment: "Settings")
        ], [
            NSLocalizedString("Support", comment: "Settings"),
            NSLocalizedString("Homepage", comment: "Settings"),
            NSLocalizedString("Twitter", comment: "Settings"),
            NSLocalizedString("Thanks to", comment: "Settings")
        ]
    ]

    var icons = [
        [
            "settings-icons-format",
            "settings-icons-editor",
            "settings-icons-night",
            "settings-icons-git",
            "settings-icons-icon",
            "settings-icons-pro"
        ], [
            "settings-icons-cloud",
            "settings-icons-external",
            "settings-icons-projects",
            "settings-icons-import"
        ], [
            "settings-icons-support",
            "settings-icons-home",
            "settings-icons-twitter",
            "settings-icons-rate"
        ]
    ]

    var rowsInSection = [6, 4, 4]

    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        title = NSLocalizedString("Settings", comment: "Sidebar settings")
        navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(done))
        navigationItem.rightBarButtonItem = Buttons.getRateUs(target: self, selector: #selector(rateUs))

        super.viewDidLoad()

        let version = UILabel(frame: CGRect(x: 8, y: 30, width: tableView.frame.width, height: 60))
        version.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        version.font = version.font.withSize(17).bold()

        if let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            version.text =
                NSLocalizedString("Version", comment: "Settings")
                + " \(versionString) "
                + NSLocalizedString("build", comment: "Settings")
                + " \(build)"
        }

        version.textColor = UIColor.lightGray
        version.textAlignment = .center

        tableView.tableFooterView = version
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowsInSection[section]
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        var cell = UITableViewCell()
        if indexPath.section == 0x02 && indexPath.row == 0x01 {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        }

        let view = UIView()
        let iconName = icons[indexPath.section][indexPath.row]
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view
        cell.textLabel?.text = rows[indexPath.section][indexPath.row]
        cell.imageView?.image = image(UIImage(named: iconName)!, withSize: CGSize(width: 40, height: 40))

        if indexPath.section == 0x00 {
            cell.accessoryType = .disclosureIndicator
            return cell
        }

        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                let uiSwitch = UISwitch()
                uiSwitch.addTarget(self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)
                uiSwitch.isOn = UserDefaultsManagement.iCloudDrive

                cell.textLabel?.text = "iCloud Drive"
                cell.accessoryView = uiSwitch
            case 1:
                cell.accessoryType = .none
            case 2:
                cell.accessoryType = .disclosureIndicator
            case 3:
                cell.detailTextLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
                cell.detailTextLabel?.numberOfLines = 0
                cell.detailTextLabel?.lineBreakMode = .byWordWrapping
                cell.detailTextLabel?.text = NSLocalizedString("Compatible with DayOne JSON (zip), Bear and Ulysses (textbundle), markdown, txt, rtf.", comment: "")
            default:
                return cell
            }
        }

        if indexPath.section == 0x02 && indexPath.row == 0x03 {
            cell.accessoryType = .disclosureIndicator
            return cell
        }

        return cell
    }

    private func image( _ image:UIImage, withSize newSize:CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, UIScreen.main.scale)
        image.draw(in: CGRect(x: 0,y: 0,width: newSize.width,height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!.withRenderingMode(.automatic)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var lvc: UIViewController?
        
        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                lvc = DefaultExtensionViewController()
            case 1:
                lvc = SettingsEditorViewController()
            case 2:
                lvc = NightModeViewController(style: .grouped)
            case 3:
                guard let project = Storage.shared().getDefault() else { return }
                lvc = AppDelegate.getGitVC(for: project)
            case 4:
                lvc = AppIconViewController()
            case 5:
                lvc = ProViewController()
            default:
                return
            }
        }

        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                break
            case 1:
                if #available(iOS 13.0, *) {
                    let viewController = ExternalViewController(documentTypes: [kUTTypeFolder as String], in: .open)
                    viewController.delegate = viewController
                    present(viewController, animated: true, completion: nil)
                }
                break
            case 2:
                lvc = ProjectsViewController()
                break
            case 3:
                let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
                if #available(iOS 11.0, *) {
                    picker.allowsMultipleSelection = true
                }
                picker.delegate = self
                self.present(picker, animated: true, completion: nil)
                break
            default: break

            }
        }

        if indexPath.section == 0x02 {
            var url: URL?

            switch indexPath.row {
            case 0x00:
                url = URL(string: "https://github.com/glushchenko/fsnotes/issues")
                break
            case 0x01:
                url = URL(string: "https://fsnot.es")
                break
            case 0x02:
                url = URL(string: "https://twitter.com/fsnotesapp")
                break
            case 0x03:
                lvc = ThanksViewController()
                break
            default: break
            }

            if let url = url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        
        if let controller = lvc {
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView(frame: CGRect(x: 25, y: 7, width: view.frame.size.width, height: 50))

        // add label
        let label = UILabel(frame: CGRect(x: 25, y: 7, width: headerView.frame.size.width, height: 50))
        label.text = sections[section]
        label.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
        headerView.addSubview(label)


        // bottom border
        let borderBottom = CALayer()
        borderBottom.mixedBackgroundColor = MixedColor(normal: 0xcdcdcf, night: 0x19191a)
        borderBottom.frame = CGRect(x: 0, y: 49.5, width: headerView.frame.size.width, height: 0.5)
        headerView.layer.addSublayer(borderBottom)

        headerView.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        return headerView
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let storageUrl = UserDefaultsManagement.storageUrl else { return }

        if let url = urls.first, url.pathExtension == "zip" {
            let storage = Storage.shared()
            let viewController = UIApplication.getVC()

            let indicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.whiteLarge)
            viewController.configureIndicator(indicator: indicator, view: self.tableView)
            viewController.startAnimation(indicator: indicator)

            self.view.isUserInteractionEnabled = false

            DispatchQueue.global().async {
                let helper = DayOneImportHelper(url: url, storage: storage)
                guard let project = helper.check() else { return }

                DispatchQueue.main.async {
                    self.view.isUserInteractionEnabled = true

                    viewController.sidebarTableView.insertRows(projects: [project])
                    viewController.sidebarTableView.select(project: project)
                    viewController.stopAnimation(indicator: indicator)

                    self.done()
                }
            }

            return
        }

        for url in urls {
            try? FileManager.default.copyItem(at: url, to: storageUrl.appendingPathComponent(url.lastPathComponent))
        }
    }

    @objc func rateUs() {
        SKStoreReviewController.requestReview()
    }

    @objc func done() {
        navigationController?.popViewController(animated: true)
    }

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell else { return }
        guard let uiSwitch = cell.accessoryView as? UISwitch else { return }

        UserDefaultsManagement.iCloudDrive = uiSwitch.isOn

        UIApplication.getVC().reloadDatabase()

        if !uiSwitch.isOn {
            UIApplication.getVC().stopCloudDriveSyncEngine()
        }
    }
}
