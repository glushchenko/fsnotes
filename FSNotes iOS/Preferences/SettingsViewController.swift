//
//  SettingsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import StoreKit
import CoreServices
import AudioToolbox

class SettingsViewController: UITableViewController, UIDocumentPickerDelegate {

    var sections = [
        NSLocalizedString("General", comment: "Settings"),
        NSLocalizedString("Library", comment: "Settings"),
        NSLocalizedString("FSNotes", comment: "Settings")
    ]

    var rows = [
        [
            NSLocalizedString("Files", comment: "Settings"),
            NSLocalizedString("Editor", comment: "Settings"),
            NSLocalizedString("Security", comment: "Settings"),
            NSLocalizedString("Git", comment: "Settings"),
            NSLocalizedString("Icon", comment: "Settings"),
            NSLocalizedString("Advanced", comment: "Settings"),
        ], [
            NSLocalizedString("iCloud Drive", comment: "Settings"),
            NSLocalizedString("Add External Folder", comment: "Settings"),
            NSLocalizedString("Folders", comment: "Settings"),
            NSLocalizedString("Import Notes", comment: "Settings")
        ], [
            NSLocalizedString("Support", comment: "Settings"),
            NSLocalizedString("Website", comment: "Settings"),
            "X",
            NSLocalizedString("Thanks", comment: "Settings")
        ]
    ]

    var icons = [
        [
            "doc.badge.gearshape.fill",
            "paragraphsign",
            "lock.fill",
            "arrow.triangle.pull",
            "square.grid.3x3.middleleft.filled",
            "atom"
        ], [
            "cloud.fill",
            "externaldrive.fill.badge.plus",
            "folder.fill.badge.gearshape",
            "square.and.arrow.down.fill"
        ], [
            "graduationcap.fill",
            "house.fill",
            "x.circle.fill",
            "heart.fill"
        ]
    ]
    
    private var gradients = [
        [
            ["#0a84ff", "#30d158"],
            ["#ff453a", "#ff9f0a"],
            ["#bf5af2", "#40c8e0"],
            ["#8e8e93", "#48484a"],
            ["#5e5ce6", "#8e8e93"],
            ["#dc1c13", "#f07470"]
        ],
        [
            ["#009bf9", "#004D7C"],
            ["#614385", "#516395"],
            ["#EA8D8D", "#A890FE"],
            ["#0D7A25", "#40AD58"]
        ],
        [
            ["#dfbd69", "#926f34"],
            ["#09203F", "#537895"],
            ["#868F96", "#596164"],
            ["#ff9966", "#ff5e62"]
        ]
    ]

    var rowsInSection = [6, 4, 4]

    override func viewDidLoad() {
        title = NSLocalizedString("Settings", comment: "Sidebar settings")
        navigationItem.rightBarButtonItem = Buttons.getRateUs(target: self, selector: #selector(rateUs))

        super.viewDidLoad()

        let version = UILabel(frame: CGRect(x: 8, y: 30, width: tableView.frame.width, height: 60))
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

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let iconName = icons[indexPath.section][indexPath.row]
        let gradient = gradients[indexPath.section][indexPath.row]
        
        var cell = SettingsTableViewCell(iconName: iconName, gradient: gradient, style: .default, reuseIdentifier: iconName)
        
        if indexPath.section == 0x01 && indexPath.row == 0x03 {
            cell = SettingsTableViewCell(iconName: iconName, gradient: gradient, style: .subtitle, reuseIdentifier: iconName)
        }

        cell.textLabel?.text = rows[indexPath.section][indexPath.row]

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
                cell.detailTextLabel?.textColor = UIColor.blackWhite
                cell.detailTextLabel?.numberOfLines = 0
                cell.detailTextLabel?.lineBreakMode = .byWordWrapping
                cell.detailTextLabel?.text = NSLocalizedString("Compatible with Bear and Ulysses (textbundle), markdown, txt.", comment: "")
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
        defer {
            tableView.deselectRow(at: indexPath, animated: false)
        }

        var lvc: UIViewController?
        
        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                lvc = DefaultExtensionViewController()
            case 1:
                lvc = SettingsEditorViewController()
            case 2:
                lvc = SecurityViewController()
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
                    let viewController = ExternalViewController(forOpeningContentTypes: [.folder], asCopy: false)
                    viewController.delegate = viewController
                    present(viewController, animated: true, completion: nil)
                }
                break
            case 2:
                lvc = ProjectsViewController()
                break
            case 3:
                var picker: UIDocumentPickerViewController

                if #available(iOS 14.0, *) {
                    picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
                } else {
                    picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
                }

                picker.allowsMultipleSelection = true
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

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let storageUrl = UserDefaultsManagement.storageUrl else { return }

        for url in urls {
            try? FileManager.default.copyItem(at: url, to: storageUrl.appendingPathComponent(url.lastPathComponent))
        }
    }

    @objc func rateUs() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            DispatchQueue.main.async {
                AudioServicesPlaySystemSound(1519)
                SKStoreReviewController.requestReview(in: scene)
            }
        }
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
