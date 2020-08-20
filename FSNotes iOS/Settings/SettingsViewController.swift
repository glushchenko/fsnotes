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

class SettingsViewController: UITableViewController, UIGestureRecognizerDelegate, UIDocumentPickerDelegate {

    var sections = [
        NSLocalizedString("General", comment: "Settings"),
        NSLocalizedString("UI", comment: "Settings"),
        NSLocalizedString("Storage", comment: "Settings"),
        "FSNotes"
    ]

    var rows = [
        [
            NSLocalizedString("Extension", comment: "Settings"),
            NSLocalizedString("Container", comment: "Settings"),
            NSLocalizedString("Default Keyboard In Editor", comment: "Settings"),
            NSLocalizedString("Files Naming", comment: "Settings"),
            NSLocalizedString("Editor", comment: "Settings")
        ], [
            NSLocalizedString("Font", comment: "Settings"),
            NSLocalizedString("Night Mode", comment: "Settings")
        ], [
            NSLocalizedString("Projects", comment: "Settings"),
            NSLocalizedString("Import notes", comment: "Settings")
        ], [
            NSLocalizedString("Support", comment: "Settings"),
            NSLocalizedString("Homepage", comment: "Settings"),
            NSLocalizedString("Twitter", comment: "Settings"),
            NSLocalizedString("Rate FSNotes", comment: "Settings")
        ]
    ]

    var icons = [
        [
            "settings-icons-format",
            "settings-icons-container",
            "settings-icons-keyboard",
            "settings-icons-naming",
            "settings-icons-editor"
        ], [
            "settings-icons-font",
            "settings-icons-night"
        ], [
            "settings-icons-projects",
            "settings-icons-import"
        ], [
            "settings-icons-support",
            "settings-icons-home",
            "settings-icons-twitter",
            "settings-icons-rate"
        ]
    ]

    var rowsInSection = [5, 2, 2, 4]
    private var prevCount = 0
        
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)
        
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        navigationController?.interactivePopGestureRecognizer?.delegate = self

        super.viewDidLoad()
        
        self.title = NSLocalizedString("Settings", comment: "Sidebar settings")

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(done))

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
        return 4
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
            switch indexPath.row {
            case 0:
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.accessoryType = .disclosureIndicator
            case 2:
                cell.accessoryType = .disclosureIndicator
            case 3:
                cell.accessoryType = .disclosureIndicator
            case 4:
                cell.accessoryType = .disclosureIndicator
            default:
                return cell
            }
        }
                
        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.accessoryType = .disclosureIndicator
            default:
                return cell
            }
        }

        if indexPath.section == 0x02 {
            switch indexPath.row {
            case 0:
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.detailTextLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
                cell.detailTextLabel?.numberOfLines = 0
                cell.detailTextLabel?.lineBreakMode = .byWordWrapping
                cell.detailTextLabel?.text = NSLocalizedString("Compatible with DayOne JSON (zip), Bear and Ulysses (textbundle), markdown, txt, rtf.", comment: "")
            default:
                return cell
            }
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
                lvc = DefaultContainerViewController()
            case 2:
                lvc = LanguageViewController()
            case 3:
                lvc = NamingViewController()
            case 4:
                lvc = SettingsEditorViewController()
            default:
                return
            }
        }
        
        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                lvc = FontViewController()
            case 1:
                lvc = NightModeViewController(style: .grouped)
            default: break
                
            }
        }

        if indexPath.section == 0x02 {
            switch indexPath.row {
            case 0:
                lvc = ProjectsViewController()
                break
            case 1:
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

        if indexPath.section == 0x03 {
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
                SKStoreReviewController.requestReview()
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

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let nc = navigationController?.viewControllers {
            self.prevCount = nc.count
            if nc.count == 1 {
                self.dismiss(animated: true)
            }
        }

        if gestureRecognizer.isEqual(navigationController?.interactivePopGestureRecognizer) {
            navigationController?.popViewController(animated: true)
        }

        return false
    }


    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let storageUrl = UserDefaultsManagement.storageUrl else { return }

        if let url = urls.first, url.pathExtension == "zip" {
            let storage = Storage.sharedInstance()
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

    @objc func done() {
        self.dismiss(animated: true, completion: nil)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        guard UserDefaultsManagement.nightModeType == .system else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkDarkMode()
        }
    }

    public func checkDarkMode() {
        if #available(iOS 12.0, *) {
            if traitCollection.userInterfaceStyle == .dark {
                if NightNight.theme != .night {
                    UIApplication.getVC().enableNightMode()
                }
            } else {
                if NightNight.theme == .night {
                    UIApplication.getVC().disableNightMode()
                }
            }
        }
    }
}
