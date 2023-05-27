//
//  SettingsEditorViewController.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 07.08.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class SettingsEditorViewController: UITableViewController {
    private var noteTableUpdater = Timer()

    private var sections = [
        NSLocalizedString("Settings", comment: ""),
        NSLocalizedString("View", comment: ""),
        NSLocalizedString("Line Spacing", comment: "Settings"),
        NSLocalizedString("Font", comment: ""),
        NSLocalizedString("Code", comment: "")
    ]

    private var rowsInSection = [2, 4, 1, 3, 2]

    private var counter = UILabel(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    
    private var rows = [
        [
            NSLocalizedString("Autocorrection", comment: "Settings"),
            NSLocalizedString("Check Spelling", comment: "Settings"),
        ],
        [
            NSLocalizedString("Code Block Live Highlighting", comment: "Settings"),
            NSLocalizedString("Live Images Preview", comment: "Settings"),
            NSLocalizedString("MathJax", comment: "Settings"),
            NSLocalizedString("SoulverCore", comment: "Settings"),
        ],
        [""],
        [
            NSLocalizedString("Family", comment: "Settings"),
            NSLocalizedString("Dynamic Type", comment: "Settings"),
            NSLocalizedString("Font Size", comment: "Settings")
        ],
        [
            NSLocalizedString("Font", comment: "Settings"),
            NSLocalizedString("Theme", comment: "Settings"),
        ]
    ]

    override func viewDidLoad() {
        title = NSLocalizedString("Editor", comment: "Settings")

        super.viewDidLoad()
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 3 && indexPath.row == 0 {
            let controller = FontViewController()
            self.navigationController?.pushViewController(controller, animated: true)
        }

        if indexPath.section == 4 && indexPath.row == 0 {
            let controller = CodeFontViewController()
            self.navigationController?.pushViewController(controller, animated: true)
        }

        if indexPath.section == 4 && indexPath.row == 1 {
            let controller = CodeThemeViewController()
            self.navigationController?.pushViewController(controller, animated: true)
        }

        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uiSwitch = UISwitch()
        uiSwitch.addTarget(self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)
        
        let cell = UITableViewCell()
        cell.textLabel?.text = rows[indexPath.section][indexPath.row]

        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.editorAutocorrection
            case 1:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.editorSpellChecking
            default:
                return cell
            }
        }

        if indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.codeBlockHighlight
            case 1:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.liveImagesPreview
            case 2:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.mathJaxPreview
            case 3:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.soulverPreview
            default:
                return cell
            }
        }

        if indexPath.section == 2 {
            let brightness = UserDefaultsManagement.editorLineSpacing
            let slider = UISlider(frame: CGRect(x: 10, y: 3, width: tableView.frame.width - 20, height: 40))
            slider.minimumValue = 0
            slider.maximumValue = 25
            slider.addTarget(self, action: #selector(didChangeLineSpacingSlider), for: .touchUpInside)
            slider.setValue(brightness, animated: true)
            cell.addSubview(slider)
        }

        if indexPath.section == 3 {
            switch indexPath.row {
            case 0:
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.accessoryView = uiSwitch
                uiSwitch.isOn = UserDefaultsManagement.dynamicTypeFont
            case 2:
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
                counter.textColor = UIColor.blackWhite
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

        if indexPath.section == 4 {
            switch indexPath.row {
            case 0:
                cell.accessoryType = .disclosureIndicator
                break
            case 1:
                cell.accessoryType = .disclosureIndicator
                break
            default:
                break
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath.section == 3 && indexPath.row == 2 && UserDefaultsManagement.dynamicTypeFont) {
            return 0
        }

        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    @objc public func switchValueDidChange(_ sender: UISwitch) {
        guard let cell = sender.superview as? UITableViewCell,
            let tableView = cell.superview as? UITableView,
            let indexPath = tableView.indexPath(for: cell) else { return }

        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.editorAutocorrection = uiSwitch.isOn

                UIApplication.getEVC().editArea.autocorrectionType = UserDefaultsManagement.editorAutocorrection ? .yes : .no
            case 1:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.editorSpellChecking = uiSwitch.isOn

                UIApplication.getEVC().editArea.spellCheckingType = UserDefaultsManagement.editorSpellChecking ? .yes : .no
            default:
                return
            }
        }

        if indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.codeBlockHighlight = uiSwitch.isOn
            case 1:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.liveImagesPreview = uiSwitch.isOn
            case 2:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.mathJaxPreview = uiSwitch.isOn
            case 3:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.soulverPreview = uiSwitch.isOn
            default:
                return
            }
        }

        if indexPath.section == 2 {
            return
        }

        if indexPath.section == 3 {
            switch indexPath.row {
            case 0:
                return
            case 1:
                guard let uiSwitch = cell.accessoryView as? UISwitch else { return }
                UserDefaultsManagement.dynamicTypeFont = uiSwitch.isOn
                if uiSwitch.isOn {
                    UserDefaultsManagement.fontSize = 17
                }

                if let dynamicCell = tableView.cellForRow(at: IndexPath(row: 2, section: 3)) {
                    dynamicCell.isHidden = uiSwitch.isOn
                }

                tableView.reloadRows(at: [IndexPath(row: 2, section: 3)], with: .automatic)

                noteTableUpdater.invalidate()
                noteTableUpdater = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(self.reloadNotesTable), userInfo: nil, repeats: false)
                return
            case 2:
                return
            default:
                return
            }
        }
    }

    @IBAction func fontSizeChanged(stepper: UIStepper) {
        UserDefaultsManagement.fontSize = Int(stepper.value)

        counter.text = String(stepper.value)

        noteTableUpdater.invalidate()
        noteTableUpdater = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(self.reloadNotesTable), userInfo: nil, repeats: false)
    }

    @IBAction func reloadNotesTable() {
        UIApplication.getVC().notesTable.reloadData()
    }

    @objc func didChangeLineSpacingSlider(sender: UISlider) {
        MPreviewView.template = nil
        UserDefaultsManagement.editorLineSpacing = sender.value
    }
}

