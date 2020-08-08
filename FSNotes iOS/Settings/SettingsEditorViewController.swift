//
//  SettingsEditorViewController.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 07.08.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class SettingsEditorViewController: UITableViewController {
    private var noteTableUpdater = Timer()

    private var counter = UILabel(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    
    private var rows = [
        NSLocalizedString("Autocorrection", comment: "Settings"),
        NSLocalizedString("Spell Checking", comment: "Settings"),
        NSLocalizedString("Code block live highlighting", comment: "Settings"),
        NSLocalizedString("Live images preview", comment: "Settings"),
        NSLocalizedString("Use inline tags", comment: "Settings"),
        NSLocalizedString("Dynamic Type", comment: "Settings"),
        NSLocalizedString("Font size", comment: "Settings")
    ]

    override func viewDidLoad() {
        view.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        navigationItem.leftBarButtonItem = Buttons.getBack(target: self, selector: #selector(cancel))

        title = NSLocalizedString("Editor", comment: "Settings")

        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header

        super.viewDidLoad()
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uiSwitch = UISwitch()
        uiSwitch.addTarget(self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)
        
        let cell = UITableViewCell()
        cell.textLabel?.text = rows[indexPath.row]

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        switch indexPath.row {
        case 0:
            cell.accessoryView = uiSwitch
            uiSwitch.isOn = UserDefaultsManagement.editorAutocorrection
        case 1:
            cell.accessoryView = uiSwitch
            uiSwitch.isOn = UserDefaultsManagement.editorSpellChecking
        case 2:
            cell.accessoryView = uiSwitch
            uiSwitch.isOn = UserDefaultsManagement.codeBlockHighlight
        case 3:
            cell.accessoryView = uiSwitch
            uiSwitch.isOn = UserDefaultsManagement.liveImagesPreview
        case 4:
            cell.accessoryView = uiSwitch
            uiSwitch.isOn = UserDefaultsManagement.inlineTags
        case 5:
            cell.accessoryView = uiSwitch
            uiSwitch.isOn = UserDefaultsManagement.dynamicTypeFont
        case 6:
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

        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath.row == 0x06 && UserDefaultsManagement.dynamicTypeFont) {
            return 0
        }

        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell,
            let tableView = cell.superview as? UITableView,
            let indexPath = tableView.indexPath(for: cell) else { return }

        switch indexPath.row {
        case 0:
            guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
            UserDefaultsManagement.editorAutocorrection = uiSwitch.isOn

            UIApplication.getEVC().editArea.autocorrectionType = UserDefaultsManagement.editorAutocorrection ? .yes : .no
        case 1:
            guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
            UserDefaultsManagement.editorSpellChecking = uiSwitch.isOn

            UIApplication.getEVC().editArea.spellCheckingType = UserDefaultsManagement.editorSpellChecking ? .yes : .no
        case 2:
            guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
            UserDefaultsManagement.codeBlockHighlight = uiSwitch.isOn
        case 3:
            guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
            UserDefaultsManagement.liveImagesPreview = uiSwitch.isOn
        case 4:
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
        case 5:
            guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
            UserDefaultsManagement.dynamicTypeFont = uiSwitch.isOn

            if let dynamicCell = tableView.cellForRow(at: IndexPath(row: 6, section: 0)) {
                dynamicCell.isHidden = uiSwitch.isOn
            }

            tableView.reloadRows(at: [IndexPath(row: 6, section: 0)], with: .automatic)

            noteTableUpdater.invalidate()
            noteTableUpdater = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(self.reloadNotesTable), userInfo: nil, repeats: false)
            return
        case 6:
            return
        default:
            return
        }
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

