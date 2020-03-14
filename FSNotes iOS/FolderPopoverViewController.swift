//
//  FolderPopoverViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/7/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class FolderPopoverViewControler : UITableViewController, UIDocumentPickerDelegate {
    var actions = [
        NSLocalizedString("Import notes", comment: ""),
        NSLocalizedString("View settings", comment: "")
    ]

    override func viewDidLoad() {
        tableView.rowHeight = 44
        tableView.separatorInset = UIEdgeInsets.zero
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()

        cell.textLabel?.text = actions[indexPath.row]
        cell.textLabel?.textAlignment = .center

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0x00 {
            let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
            if #available(iOS 11.0, *) {
                picker.allowsMultipleSelection = true
            }
            picker.delegate = self
            self.present(picker, animated: true, completion: nil)
            return
        }

        if indexPath.row == 0x01 {
            guard let mvc = getMainVC() else { return }

            var currentProject = mvc.sidebarTableView.getSidebarItem()?.project
            if currentProject == nil {
                currentProject = Storage.sharedInstance().getCurrentProject()
            }

            guard let project = currentProject else { return }

            let projectController = ProjectSettingsViewController(project: project, dismiss: true)

            let controller = UINavigationController(rootViewController: projectController)


            self.dismiss(animated: true, completion: nil)
            mvc.present(controller, animated: true, completion: nil)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        guard var projectURL = Storage.sharedInstance().getCurrentProject()?.url else { return }

        if let mvc = getMainVC(), let pURL = mvc.sidebarTableView.getSidebarItem()?.project?.url {
            projectURL = pURL
        }

        for url in urls {
            let dstURL = projectURL.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dstURL)
        }

        self.dismiss(animated: true, completion: nil)
    }

    public func getMainVC() -> ViewController? {
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let mvc = pageController.mainViewController
            else { return nil }

        return mvc
    }
}
