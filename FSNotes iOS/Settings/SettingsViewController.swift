//
//  SettingsViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 2/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class SettingsViewController: UITableViewController, UIGestureRecognizerDelegate, UIDocumentPickerDelegate {
    
    var sections = ["General", "Editor", "UI", "Storage", "FSNotes"]
    var rows = [
        ["Default Extension", "Default Keyboard In Editor"],
        ["Code block live highlighting", "Live images preview"],
        ["Font", "Night Mode"],
        ["Projects", "Import notes"],
        ["Support", "Homepage", "Twitter"]
    ]

    var rowsInSection = [2, 2, 2, 2, 3]
    private var prevCount = 0
        
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x2e2c32)
        
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        navigationController?.interactivePopGestureRecognizer?.delegate = self


        super.viewDidLoad()
        
        self.title = "Settings"

        self.navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(done))
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
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
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        
        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view
        cell.textLabel?.text = rows[indexPath.section][indexPath.row]
        
        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.accessoryType = .disclosureIndicator
            default:
                return cell
            }
        }
        
        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                cell.accessoryType = UserDefaultsManagement.codeBlockHighlight ? .checkmark : .none
            case 1:
                cell.accessoryType = UserDefaultsManagement.liveImagesPreview ? .checkmark : .none
            default:
                return cell
            }
        }
        
        if indexPath.section == 0x02 {
            switch indexPath.row {
            case 0:
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.accessoryType = .disclosureIndicator
            default:
                return cell
            }
        }

        if indexPath.section == 0x03 {
            switch indexPath.row {
            case 0:
                cell.accessoryType = .disclosureIndicator
            default:
                return cell
            }
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var lvc: UIViewController?
        
        if indexPath.section == 0x00 {
            switch indexPath.row {
            case 0:
                lvc = DefaultExtensionViewController()
            case 1:
                lvc = LanguageViewController()
            default:
                return
            }
        }
        
        if indexPath.section == 0x01 {
            if let cell = tableView.cellForRow(at: indexPath) {
                if cell.accessoryType == .none {
                    cell.accessoryType = .checkmark
                    
                } else {
                    cell.accessoryType = .none
                }
                
                if indexPath.row == 1 {
                    UserDefaultsManagement.liveImagesPreview = (cell.accessoryType == .checkmark)
                } else {
                    UserDefaultsManagement.codeBlockHighlight = (cell.accessoryType == .checkmark)
                }
            }
        }
        
        if indexPath.section == 0x02 {
            switch indexPath.row {
            case 0:
                lvc = FontViewController()
            case 1:
                lvc = NightModeViewController(style: .grouped)
            default: break
                
            }
        }

        if indexPath.section == 0x03 {
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

        if indexPath.section == 0x04 {
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
            default: break
            }

            if let url = url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }

            tableView.deselectRow(at: indexPath, animated: false)
        }
        
        if let controller = lvc {
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }


    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 4 || section == 3 {
            return 65
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard self.sections[section] == "FSNotes" || self.sections[section] == "Storage" else { return nil }

        let tableViewFooter = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 50))

        if self.sections[section] == "FSNotes" {
            let version = UILabel(frame: CGRect(x: 8, y: 15, width: tableView.frame.width, height: 30))
            version.font = version.font.withSize(17).bold()

            if let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                version.text = "Version \(versionString) build \(build)"
            }

            version.textColor = UIColor.lightGray
            version.textAlignment = .center
            tableViewFooter.addSubview(version)
            return tableViewFooter
        }

        if self.sections[section] == "Storage" {
            let label = UILabel(frame: CGRect(x: 20, y: 0, width: tableView.frame.width - 20, height: 60))
            label.font = label.font.withSize(15)
            label.text = "Compatible with DayOne JSON (zip), Bear and Ulysses (textbundle), markdown, txt, rtf."
            label.textColor = UIColor.lightGray
            label.numberOfLines = 2
            tableViewFooter.addSubview(label)
            return tableViewFooter
        }

        return nil
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

            let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
            viewController.configureIndicator(indicator: indicator, view: self.tableView)

            self.view.isUserInteractionEnabled = false

            DispatchQueue.global().async {
                let helper = DayOneImportHelper(url: url, storage: storage)
                let project = helper.check()

                DispatchQueue.main.async {
                    self.view.isUserInteractionEnabled = true

                    viewController.reloadSidebar(select: project)
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
}
