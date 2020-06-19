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

    private var noteTableUpdater = Timer()
    private var counter = UILabel(frame: CGRect(x: 0, y: 0, width: 20, height: 20))

    var sections = [
        NSLocalizedString("General", comment: "Settings"),
        NSLocalizedString("Editor", comment: "Settings"),
        NSLocalizedString("UI", comment: "Settings"),
        NSLocalizedString("Storage", comment: "Settings"),
        NSLocalizedString("FSNotes", comment: "Settings")
    ]

    var rows = [
        [
            NSLocalizedString("Extension", comment: "Settings"),
            NSLocalizedString("Container", comment: "Settings"),
            NSLocalizedString("Default Keyboard In Editor", comment: "Settings"),
            NSLocalizedString("Files Naming", comment: "Settings")
        ], [
            NSLocalizedString("Code block live highlighting", comment: "Settings"),
            NSLocalizedString("Live images preview", comment: "Settings"),
            NSLocalizedString("Use inline tags", comment: "Settings"),
            NSLocalizedString("Dynamic Type", comment: "Settings"),
            NSLocalizedString("Font size", comment: "Settings")
        ], [
            NSLocalizedString("Font", comment: "Settings"),
            NSLocalizedString("Night Mode", comment: "Settings")
        ], [
            NSLocalizedString("Projects", comment: "Settings"),
            NSLocalizedString("Import notes", comment: "Settings")
        ], [
            NSLocalizedString("Support", comment: "Settings"),
            NSLocalizedString("Homepage", comment: "Settings"),
            NSLocalizedString("Twitter", comment: "Settings")
        ]
    ]

    var rowsInSection = [3, 5, 2, 2, 3]
    private var prevCount = 0
        
    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)
        
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        navigationController?.interactivePopGestureRecognizer?.delegate = self


        super.viewDidLoad()
        
        self.title = NSLocalizedString("Settings", comment: "Sidebar settings")

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
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uiSwitch = UISwitch()
        uiSwitch.addTarget(self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)

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
            case 2:
                cell.accessoryType = .disclosureIndicator
            case 3:
                cell.accessoryType = .disclosureIndicator
            default:
                return cell
            }
        }
        
        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.codeBlockHighlight
            case 1:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.liveImagesPreview
            case 2:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.inlineTags
            case 3:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.dynamicTypeFont
            case 4:
                if UserDefaultsManagement.dynamicTypeFont {
                    cell.isHidden = true
                    return cell
                }

                let stepper = UIStepper(frame: CGRect(x: 20, y: 20, width: 100, height: 20))
                stepper.stepValue = 1
                stepper.minimumValue = 10
                stepper.maximumValue = 40
                stepper.value = Double(UserDefaultsManagement.fontSize)
                stepper.translatesAutoresizingMaskIntoConstraints = false
                stepper.addTarget(self, action: #selector(fontSizeChanged), for: .valueChanged)

                let label = UILabel()
                label.text = ""
                label.translatesAutoresizingMaskIntoConstraints = false

                counter.text = String(Double(UserDefaultsManagement.fontSize))
                counter.mixedTextColor = MixedColor(normal: UIColor.gray, night: UIColor.white)
                counter.translatesAutoresizingMaskIntoConstraints = false

                cell.contentView.addSubview(label)
                cell.contentView.addSubview(counter)
                cell.contentView.addSubview(stepper)
                cell.selectionStyle = .none
                cell.accessoryType = .none

                let views = ["name" : label, "counter": counter, "stepper" : stepper] as [String : Any]

                cell.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[name]-[counter(40)]-15-[stepper(100)]-20-|", options:  NSLayoutConstraint.FormatOptions.alignAllCenterY, metrics: nil, views: views))

                cell.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[name(stepper)]-10-|", options: [], metrics: nil, views: views))
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

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell,
            let tableView = cell.superview as? UITableView,
            let indexPath = tableView.indexPath(for: cell) else { return }

        if indexPath.section == 0x01 {
            switch indexPath.row {
            case 0:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.codeBlockHighlight = uiSwitch.isOn
            case 1:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.liveImagesPreview = uiSwitch.isOn
            case 2:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.inlineTags = uiSwitch.isOn

                let vc = UIApplication.getVC()
                if UserDefaultsManagement.inlineTags {
                    vc.sidebarTableView.loadAllTags()
                } else {
                    vc.sidebarTableView.unloadAllTags()
                }

                vc.resizeSidebar(withAnimation: true)

                UIApplication.getEVC().resetToolbar()
            case 3:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.dynamicTypeFont = uiSwitch.isOn

                if let dynamicCell = tableView.cellForRow(at: IndexPath(row: 4, section: 1)) {
                    dynamicCell.isHidden = uiSwitch.isOn
                }

                tableView.reloadRows(at: [IndexPath(row: 4, section: 1)], with: .automatic)

                noteTableUpdater.invalidate()
                noteTableUpdater = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(self.reloadNotesTable), userInfo: nil, repeats: false)
                return
            case 4:
                return
            default:
                return
            }
        }
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
            default:
                return
            }
        }

        if indexPath.section == 0x01 {
            tableView.deselectRow(at: indexPath, animated: false)
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
        guard self.sections[section] == "FSNotes" || self.sections[section] == NSLocalizedString("Storage", comment: "") else { return nil }

        let tableViewFooter = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 50))

        if self.sections[section] == "FSNotes" {
            let version = UILabel(frame: CGRect(x: 8, y: 15, width: tableView.frame.width, height: 30))
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
            tableViewFooter.addSubview(version)
            return tableViewFooter
        }

        if self.sections[section] == NSLocalizedString("Storage", comment: "") {
            let label = UILabel(frame: CGRect(x: 20, y: 0, width: tableView.frame.width - 20, height: 60))
            label.font = label.font.withSize(15)
            label.text = NSLocalizedString("Compatible with DayOne JSON (zip), Bear and Ulysses (textbundle), markdown, txt, rtf.", comment: "")
            label.textColor = UIColor.lightGray
            label.numberOfLines = 2
            tableViewFooter.addSubview(label)
            return tableViewFooter
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath.section == 0x01 && indexPath.row == 0x04 && UserDefaultsManagement.dynamicTypeFont) {
            return 0
        }

        return super.tableView(tableView, heightForRowAt: indexPath)
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

    @IBAction func fontSizeChanged(stepper: UIStepper) {
        UserDefaultsManagement.fontSize = Int(stepper.value)

        counter.text = String(stepper.value)

        noteTableUpdater.invalidate()
        noteTableUpdater = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(self.reloadNotesTable), userInfo: nil, repeats: false)
    }

    @IBAction func reloadNotesTable() {
        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = pc.containerController.viewControllers[0] as? ViewController else { return }

        vc.notesTable.reloadData()
    }
}
