//
//  ViewController+More.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 10.01.2021.
//  Copyright © 2021 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit

extension ViewController: UIDocumentPickerDelegate {
    @IBAction public func openSidebarSettings() {
        let mvc = UIApplication.getVC()
        if notesTable.isEditing {
            if let selectedRows = mvc.notesTable.selectedIndexPaths {
                var notes = [Note]()
                for indexPath in selectedRows {
                    if mvc.notesTable.notes.indices.contains(indexPath.row) {
                        let note = mvc.notesTable.notes[indexPath.row]
                        notes.append(note)
                    }
                }

                mvc.notesTable.selectedIndexPaths = nil
                mvc.notesTable.actionsSheet(notes: notes, presentController: self)
            } else {
                mvc.notesTable.allowsMultipleSelectionDuringEditing = false
                mvc.notesTable.setEditing(false, animated: true)
            }
            return
        }

        let sidebarItem = sidebarTableView.getSidebarItem()
        let projectLabel = sidebarItem?.project?.getFullLabel() ?? String()

        var type = sidebarItem?.type
        var indexPath: IndexPath?

        if let tag = searchQuery.tag {
            indexPath = sidebarTableView.getIndexPathBy(tag: tag)
        }

        if let path = indexPath, path.section == SidebarSection.Tags.rawValue {
            type = .Tag
        }

        guard type != .Label else { return }

        var actions = [FolderPopoverActions]()

        switch type {
        case .Inbox:
            actions = [.importNote, .settingsFolder, .createFolder, .multipleSelection, .openInFiles]
        case .All, .Todo:
            actions = [.settingsFolder, .multipleSelection]
        case .Archive:
            actions = [.importNote, .settingsFolder, .multipleSelection, .openInFiles]
        case .Trash:
            actions = [.settingsFolder, .multipleSelection, .openInFiles, .emptyBin]
        case .Category:
            actions = [.importNote, .settingsFolder, .createFolder, .removeFolder, .renameFolder, .multipleSelection, .openInFiles]
        case .Tag:
            actions = [.removeTag, .renameTag, .multipleSelection]
        case .Untagged:
            actions = [.multipleSelection]
        default: break
        }

        var mainTitle = type != .Tag && type == .Project ? projectLabel : sidebarItem?.getName()

        if type == .Untagged {
            mainTitle = NSLocalizedString("Untagged", comment: "")
        }

        let actionSheet = UIAlertController(title: mainTitle, message: nil, preferredStyle: .actionSheet)

        if actions.contains(.removeFolder) {
            let title = NSLocalizedString("Remove folder", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .destructive, handler: { _ in
                self.removeFolder()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "sidebarRemoveFolder")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.emptyBin) {
            let title = NSLocalizedString("Empty Bin", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .destructive, handler: { _ in
                self.emptyBin()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "emptyBin")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }
        
        if actions.contains(.importNote) {
            let title = NSLocalizedString("Import notes", comment: "Main view popover table")
            let importNote = UIAlertAction(title:title, style: .default, handler: { _ in
                self.importNote()
            })
            importNote.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

            if let image = UIImage(named: "sidebarImport")?.resize(maxWidthHeight: 22) {
                importNote.setValue(image, forKey: "image")
            }

            actionSheet.addAction(importNote)
        }

        if actions.contains(.settingsFolder) {
            let title = NSLocalizedString("View settings", comment: "Main view popover table")
            let settings = UIAlertAction(title:title, style: .default, handler: { _ in
                self.openProjectSettings()
            })
            settings.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "sidebarSettings")?.resize(maxWidthHeight: 23) {
                settings.setValue(image, forKey: "image")
            }
            actionSheet.addAction(settings)
        }

        if actions.contains(.multipleSelection) {
            let title = NSLocalizedString("Select", comment: "Main view popover table")
            let multipleSelection = UIAlertAction(title:title, style: .default, handler: { _ in
                self.bulkEditing()
            })
            multipleSelection.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "navigationBulk")?.resize(maxWidthHeight: 23) {
                multipleSelection.setValue(image, forKey: "image")
            }
            actionSheet.addAction(multipleSelection)
        }

        if actions.contains(.createFolder) {
            let title = NSLocalizedString("Create folder", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.createFolder()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "sidebarCreateFolder")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.renameFolder) {
            let title = NSLocalizedString("Rename folder", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.renameFolder()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "sidebarRenameFolder")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.removeTag) {
            let title = NSLocalizedString("Remove tag", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .destructive, handler: { _ in
                self.removeTag()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "sidebarRemoveTag")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.renameTag) {
            let title = NSLocalizedString("Rename tag", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.renameTag()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "sidebarRenameTag")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.openInFiles) {
            let title = NSLocalizedString("Open in Files.app", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.openInFiles()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "openInFiles")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        let dismiss = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        actionSheet.addAction(dismiss)

        actionSheet.popoverPresentationController?.sourceView = view
        actionSheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.size.width / 2.0, y: view.bounds.size.height, width: 2.0, height: 1.0)

        present(actionSheet, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard var projectURL = Storage.sharedInstance().getCurrentProject()?.url else { return }

        let mvc = UIApplication.getVC()
        if let pURL = mvc.sidebarTableView.getSidebarItem()?.project?.url {
            projectURL = pURL
        }

        for url in urls {
            let dstURL = projectURL.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dstURL)
        }

        self.dismiss(animated: true, completion: nil)
    }

    private func importNote() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        if #available(iOS 11.0, *) {
            picker.allowsMultipleSelection = true
        }
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }

    @objc public func openProjectSettings() {
        let vc = UIApplication.getVC()
        guard let sidebarItem = vc.sidebarTableView.getSidebarItem()
        else { return }

        let storage = Storage.shared()

        // All projects

        var currentProject = sidebarItem.project
        if currentProject == nil {
            currentProject = storage.getCurrentProject()
        }

        // Virtual projects Notes and Todo

        if sidebarItem.type == .Todo || sidebarItem.type == .All {
            currentProject = sidebarItem.project
        }

        guard let project = currentProject else { return }

        let projectController = ProjectSettingsViewController(project: project, dismiss: true)
        let controller = UINavigationController(rootViewController: projectController)

        self.dismiss(animated: true, completion: nil)
        vc.present(controller, animated: true, completion: nil)
    }

    @objc func bulkEditing() {
        let mvc = UIApplication.getVC()

        if !mvc.notesTable.isEditing {
            mvc.notesTable.allowsMultipleSelectionDuringEditing = true
            mvc.notesTable.setEditing(true, animated: true)
        }
    }

    private func createFolder() {
        let mvc = UIApplication.getVC()
        guard let selectedProject = mvc.searchQuery.project
        else { return }

        let alertController = UIAlertController(title: NSLocalizedString("Create folder:", comment: ""), message: nil, preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            [] (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Enter folder name", comment: "")
        })

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            let newDir = selectedProject.url.appendingPathComponent(name, isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print(error)
                return
            }

            let storage = Storage.shared()
            let project = Project(
                storage: storage,
                url: newDir,
                label: name,
                isTrash: false,
                isRoot: false,
                parent: selectedProject,
                isDefault: false,
                isArchive: false
            )

            storage.assignTree(for: project)
            mvc.sidebarTableView.insertRows(projects: [project])
        }

        let title = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: title, style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.dismiss(animated: true, completion: nil)
        mvc.present(alertController, animated: true) {
            alertController.textFields![0].selectAll(nil)
        }
    }

    private func removeFolder() {
        let mvc = UIApplication.getVC()

        guard let selectedProject = mvc.searchQuery.project
        else { return }

        let alert = UIAlertController(
            title: "Folder removing 🚨",
            message: "Are you really want to remove \"\(selectedProject.label)\"? Folder content will be deleted, action can not be undone.",
            preferredStyle: UIAlertController.Style.alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction!) in

            mvc.sidebarTableView.removeRows(projects: [selectedProject])

            if !selectedProject.isExternal {
                try? FileManager.default.removeItem(at: selectedProject.url)
            }

            Storage.shared().remove(project: selectedProject)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
        }))

        if selectedProject.isExternal {
            let bookmark = SandboxBookmark.sharedInstance()
            bookmark.remove(url: selectedProject.url)

            mvc.sidebarTableView.removeRows(projects: [selectedProject])
        } else {
            mvc.present(alert, animated: true, completion: nil)
        }
    }

    private func renameFolder() {
        let mvc = UIApplication.getVC()

        guard let selectedProject = mvc.searchQuery.project
        else { return }

        let title = NSLocalizedString("Rename folder:", comment: "Popover table")
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            [] (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Enter folder name", comment: "")
            textField.text = selectedProject.url.lastPathComponent
        })

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            let newDir = selectedProject.url
                .deletingLastPathComponent()
                .appendingPathComponent(name, isDirectory: true)

            do {
                try FileManager.default.moveItem(at: selectedProject.url, to: newDir)
            } catch {
                print(error)
                return
            }

            mvc.sidebarTableView.removeRows(projects: [selectedProject])
            mvc.storage.unload(project: selectedProject)

            selectedProject.url = newDir
            selectedProject.loadLabel()

            mvc.storage.loadNotes(selectedProject)
            mvc.sidebarTableView.insertRows(projects: [selectedProject])
            mvc.sidebarTableView.select(project: selectedProject)
        }

        let cancel = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: cancel, style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.dismiss(animated: true, completion: nil)
        mvc.present(alertController, animated: true) {
            alertController.textFields![0].selectAll(nil)
        }
    }

    private func removeTag() {
        let mvc = UIApplication.getVC()

        guard let selectedProject = mvc.searchQuery.project,
            let tag = mvc.searchQuery.tag
        else { return }

        let notes =
            mvc.storage.noteList
                .filter({ $0.project == selectedProject })
                .filter({ $0.tags.contains(tag) })

        for note in notes {
            note.replace(tag: "#\(tag)", with: "")
            note.tags.removeAll(where: { $0 == tag })
        }

        mvc.sidebarTableView.remove(tag: tag)
        self.dismiss(animated: true, completion: nil)
    }

    private func renameTag() {
        let mvc = UIApplication.getVC()

        guard let selectedProject = mvc.searchQuery.project,
            let tag = mvc.searchQuery.tag
        else { return }

        let title = NSLocalizedString("Rename tag:", comment: "Popover table")
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            [] (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Enter new tag name", comment: "")
            textField.text = tag
        })

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard var name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            name = name.withoutSpecialCharacters

            guard name.count > 1 else { return }

            let notes =
                mvc.storage.noteList
                    .filter({ $0.project == selectedProject })
                    .filter({ $0.tags.contains(tag) })

            for note in notes {
                note.replace(tag: "#\(tag)", with: "#\(name)")
                note.tags.removeAll(where: { $0 == tag })
                _ = note.scanContentTags()
            }

            mvc.sidebarTableView.remove(tag: tag)
            mvc.sidebarTableView.insert(tags: [name])

            self.dismiss(animated: true, completion: nil)
        }

        let cancel = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: cancel, style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.dismiss(animated: true, completion: nil)
        mvc.present(alertController, animated: true) {
            alertController.textFields![0].selectAll(nil)
        }
    }

    private func openInFiles() {
        let mvc = UIApplication.getVC()

        guard let selectedProject = mvc.searchQuery.project else { return }
        guard let path = selectedProject.url.path.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed) else { return }

        if let projectUrl = URL(string: "shareddocuments://" + path) {
            UIApplication.shared.open(projectUrl, options: [:])
        }
    }

    private func emptyBin() {
        let notes = storage.getAllTrash()

        storage.removeNotes(notes: notes, fsRemove: true, completely: true) { [self]_ in
            self.notesTable.removeRows(notes: notes)
        }
    }
}
