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
    
    func makeSidebarSettingsMenu(for sidebarItem: SidebarItem) -> UIMenu? {
        let handler: (_ action: UIAction) -> () = { action in
        switch action.identifier.rawValue {
            case "emptyBin":
                self.emptyBin()
            case "importNote":
                self.importNote()
            case "viewSettings":
                self.openProjectSettings()
            case "gitSettings":
                self.openGitSettings()
            case "bulkEditing":
                self.bulkEditing()
            case "createFolder":
                self.createFolder()
            case "removeFolder":
                self.removeFolder()
            case "renameFolder":
                self.renameFolder()
            case "removeTag":
                self.removeTag()
            case "renameTag":
                self.renameTag()
            case "openInFiles":
                self.openInFiles()
            case "lockFolder":
                self.lockProject()
            case "unlockFolder":
                self.unlockProject()
            case "decryptFolder":
                self.decryptProject()
            case "encryptFolder":
                self.encryptProject()
            default:
                break
            }
        }

        // Build popovers

        var popoverActions = [FolderPopoverActions]()
        switch sidebarItem.type {
        case .Inbox:
            popoverActions = [.importNote, .settingsFolder, .createFolder, .multipleSelection, .openInFiles, .settingsRepository]
        case .All, .Todo:
            popoverActions = [.settingsFolder, .multipleSelection]
        case .Archive:
            popoverActions = [.importNote, .settingsFolder, .multipleSelection, .openInFiles]
        case .Trash:
            popoverActions = [.settingsFolder, .multipleSelection, .openInFiles, .emptyBin]
        case .Project:
            popoverActions = [.importNote, .settingsFolder, .createFolder, .removeFolder, .renameFolder, .multipleSelection, .openInFiles, .settingsRepository, .encryptFolder]
        case .Tag:
            popoverActions = [.removeTag, .renameTag, .multipleSelection]
        case .Untagged:
            popoverActions = [.multipleSelection]
        case .ProjectEncryptedLocked:
            popoverActions = [.unLockFolder, .decryptFolder, .settingsFolder, .removeFolder, .renameFolder, .multipleSelection, .openInFiles, .settingsRepository]
        case .ProjectEncryptedUnlocked:
            popoverActions = [.lockFolder, .decryptFolder, .importNote, .settingsFolder, .createFolder, .removeFolder, .renameFolder, .multipleSelection, .openInFiles, .settingsRepository]
        default: break
        }

        // Build actions

        var actions = [UIAction]()
        if popoverActions.contains(.removeFolder) {
            let title = NSLocalizedString("Remove folder", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "trash"), identifier: UIAction.Identifier("removeFolder"), attributes: .destructive, handler: handler))
        }

        if popoverActions.contains(.emptyBin) {
            let title = NSLocalizedString("Empty Bin", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "xmark.circle"), identifier: UIAction.Identifier("emptyBin"), handler: handler))
        }

        if popoverActions.contains(.importNote) {
            let title = NSLocalizedString("Import notes", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "square.and.arrow.down"), identifier: UIAction.Identifier("importNote"), handler: handler))
        }

        if popoverActions.contains(.settingsFolder) {
            let title = NSLocalizedString("View settings", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "gearshape"), identifier: UIAction.Identifier("viewSettings"), handler: handler))
        }

        if popoverActions.contains(.settingsRepository) {
            let title = NSLocalizedString("Git settings", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(named: "gitSettings"), identifier: UIAction.Identifier("gitSettings"), handler: handler))
        }

        if popoverActions.contains(.multipleSelection) {
            let title = NSLocalizedString("Select", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "checkmark.circle"), identifier: UIAction.Identifier("bulkEditing"), handler: handler))
        }

        if popoverActions.contains(.createFolder) {
            let title = NSLocalizedString("Create folder", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "folder.badge.plus"), identifier: UIAction.Identifier("createFolder"), handler: handler))
        }

        if popoverActions.contains(.renameFolder) {
            let title = NSLocalizedString("Rename folder", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "pencil.circle"), identifier: UIAction.Identifier("renameFolder"), handler: handler))
        }

        if popoverActions.contains(.removeTag) {
            let title = NSLocalizedString("Remove tag", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "tag.slash"), identifier: UIAction.Identifier("removeTag"), handler: handler))
        }

        if popoverActions.contains(.renameTag) {
            let title = NSLocalizedString("Rename tag", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "pencil.circle"), identifier: UIAction.Identifier("renameTag"), handler: handler))
        }

        if popoverActions.contains(.openInFiles) {
            let title = NSLocalizedString("Open in Files.app", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "folder"), identifier: UIAction.Identifier("openInFiles"), handler: handler))
        }

        if popoverActions.contains(.lockFolder) {
            let title = FolderPopoverActions.lockFolder.getDescription()
            actions.append(UIAction(title: title, image: UIImage(systemName: "lock"), identifier: UIAction.Identifier("lockFolder"), handler: handler))
        }

        if popoverActions.contains(.unLockFolder) {
            let title = FolderPopoverActions.unLockFolder.getDescription()
            actions.append(UIAction(title: title, image: UIImage(systemName: "lock.open"), identifier: UIAction.Identifier("unlockFolder"), handler: handler))
        }

        if popoverActions.contains(.decryptFolder) {
            let title = FolderPopoverActions.decryptFolder.getDescription()
            actions.append(UIAction(title: title, image: UIImage(systemName: "lock.slash"), identifier: UIAction.Identifier("decryptFolder"), handler: handler))
        }

        if popoverActions.contains(.encryptFolder) {
            let title = FolderPopoverActions.encryptFolder.getDescription()
            actions.append(UIAction(title: title, image: UIImage(systemName: "lock"), identifier: UIAction.Identifier("encryptFolder"), handler: handler))
        }

        // Build title

        var mainTitle = String()
        switch sidebarItem.type {
        case .Project:
            if let project = sidebarItem.project {
                mainTitle = project.getFullLabel()
            }
        case .Untagged:
            mainTitle = NSLocalizedString("Untagged", comment: "")
        default:
            mainTitle = sidebarItem.getName()
        }

        return UIMenu(title: mainTitle,  children: actions)
    }


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
            actions = [.importNote, .settingsFolder, .createFolder, .multipleSelection, .openInFiles, .settingsRepository]
        case .All, .Todo:
            actions = [.settingsFolder, .multipleSelection]
        case .Archive:
            actions = [.importNote, .settingsFolder, .multipleSelection, .openInFiles]
        case .Trash:
            actions = [.settingsFolder, .multipleSelection, .openInFiles, .emptyBin]
        case .Project:
            actions = [.importNote, .settingsFolder, .createFolder, .removeFolder, .renameFolder, .multipleSelection, .openInFiles, .settingsRepository, .encryptFolder]
        case .Tag:
            actions = [.removeTag, .renameTag, .multipleSelection]
        case .Untagged:
            actions = [.multipleSelection]
        case .ProjectEncryptedLocked:
            actions = [.unLockFolder, .decryptFolder, .importNote, .settingsFolder, .createFolder, .removeFolder, .renameFolder, .multipleSelection, .openInFiles, .settingsRepository]
        case .ProjectEncryptedUnlocked:
            actions = [.lockFolder, .decryptFolder, .importNote, .settingsFolder, .createFolder, .removeFolder, .renameFolder, .multipleSelection, .openInFiles, .settingsRepository]
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
            if let image = UIImage(systemName: "trash")?.resize(maxWidthHeight: 23) {
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
            if let image = UIImage(systemName: "xmark.circle")?.resize(maxWidthHeight: 23) {
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

            if let image = UIImage(systemName: "square.and.arrow.down")?.resize(maxWidthHeight: 23) {
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
            if let image = UIImage(systemName: "gearshape")?.resize(maxWidthHeight: 23) {
                settings.setValue(image, forKey: "image")
            }
            actionSheet.addAction(settings)
        }

        if actions.contains(.settingsRepository) {
            let title = NSLocalizedString("Git settings", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.openGitSettings()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "gitSettings")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.multipleSelection) {
            let title = NSLocalizedString("Select", comment: "Main view popover table")
            let multipleSelection = UIAlertAction(title:title, style: .default, handler: { _ in
                self.bulkEditing()
            })
            multipleSelection.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "checkmark.circle")?.resize(maxWidthHeight: 23) {
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
            if let image = UIImage(systemName: "folder.badge.plus")?.resize(maxWidthHeight: 23) {
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
            if let image = UIImage(systemName: "pencil.circle")?.resize(maxWidthHeight: 23) {
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
            if let image = UIImage(systemName: "tag.slash")?.resize(maxWidthHeight: 23) {
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
            if let image = UIImage(systemName: "pencil.circle")?.resize(maxWidthHeight: 23) {
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
            if let image = UIImage(systemName: "folder")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.lockFolder) {
            let title = FolderPopoverActions.lockFolder.getDescription()
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.lockProject()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "lock")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.unLockFolder) {
            let title = FolderPopoverActions.unLockFolder.getDescription()
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.unlockProject()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "lock.open")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.decryptFolder) {
            let title = FolderPopoverActions.decryptFolder.getDescription()
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.decryptProject()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "lock.slash")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.encryptFolder) {
            let title = FolderPopoverActions.encryptFolder.getDescription()
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.encryptProject()
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "lock")?.resize(maxWidthHeight: 23) {
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
        guard var projectURL = Storage.shared().getCurrentProject()?.url else { return }

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

            mvc.notesTable.loadBulkBarButtomItem()
        }
    }

//    let mvc = UIApplication.getVC()
//    if notesTable.isEditing {
//        if let selectedRows = mvc.notesTable.selectedIndexPaths {
//            var notes = [Note]()
//            for indexPath in selectedRows {
//                if mvc.notesTable.notes.indices.contains(indexPath.row) {
//                    let note = mvc.notesTable.notes[indexPath.row]
//                    notes.append(note)
//                }
//            }
//
//            mvc.notesTable.selectedIndexPaths = nil
//            mvc.notesTable.actionsSheet(notes: notes, presentController: self)
//        } else {
//            mvc.notesTable.allowsMultipleSelectionDuringEditing = false
//            mvc.notesTable.setEditing(false, animated: true)
//        }
//        return UIMenu(title: "",  children: [])
//    }

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

            mvc.storage.loadNotes(selectedProject, loadContent: true)
            mvc.sidebarTableView.insertRows(projects: [selectedProject])
            mvc.sidebarTableView.select(project: selectedProject)

            // Load tags for new urls
            let notes = selectedProject.getNotes()
            mvc.sidebarTableView.loadTags(notes: notes)
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

    private func openGitSettings() {
        let vc = UIApplication.getVC()
        guard let sidebarItem = vc.sidebarTableView.getSidebarItem() else { return }

        let storage = Storage.shared()

        // All projects

        var currentProject = sidebarItem.project
        if currentProject == nil {
            currentProject = storage.getCurrentProject()
        }

        guard let project = currentProject else { return }

        let projectController = AppDelegate.getGitVC(for: project)
        let controller = UINavigationController(rootViewController: projectController)

        self.dismiss(animated: true, completion: nil)
        vc.present(controller, animated: true, completion: nil)
    }

    private func emptyBin() {
        let notes = storage.getAllTrash()

        storage.removeNotes(notes: notes, fsRemove: true, completely: true) { [self]_ in
            self.notesTable.removeRows(notes: notes)
        }
    }

    @objc public func unlockProject(createNote: Bool = false) {
        guard let selectedProject = searchQuery.project else { return }

        getMasterPassword() { password in
            let result = selectedProject.unlock(password: password)

            DispatchQueue.main.async {
                self.sidebarTableView.loadTags(notes: result.1)
                self.disableLockedProject()

                if let indexPath = self.sidebarTableView.getIndexPathBy(project: selectedProject),
                   let sidebarItem = self.sidebarTableView.getSidebarItem(project: selectedProject) {
                    sidebarItem.load(type: .ProjectEncryptedUnlocked)
                    self.sidebarTableView.reloadRows(at: [indexPath], with: .automatic)
                    self.sidebarTableView.select(project: selectedProject)

                    if createNote {
                        self.createNote()
                    }
                }

                self.reloadNotesTable()
            }
        }
    }

    @objc public func lockProject() {
        guard let selectedProject = searchQuery.project else { return }
        let locked = selectedProject.lock()
        selectedProject.removeCache()

        DispatchQueue.main.async {
            guard locked.count > 0 else {
                self.wrongPassAlert()
                return
            }

            self.sidebarTableView.loadTags(notes: locked)

            self.enableLockedProject()
            self.reloadNotesTable()

            if let indexPath = self.sidebarTableView.getIndexPathBy(project: selectedProject),
               let sidebarItem = self.sidebarTableView.getSidebarItem(project: selectedProject) {
                sidebarItem.load(type: .ProjectEncryptedLocked)
                self.sidebarTableView.reloadRows(at: [indexPath], with: .automatic)
                self.sidebarTableView.select(project: selectedProject)
            }
        }
    }

    @objc public func encryptProject() {
        guard let selectedProject = searchQuery.project else { return }

        getMasterPassword() { password in
            let encrypted = selectedProject.encrypt(password: password)
            selectedProject.removeCache()

            DispatchQueue.main.async {
                self.sidebarTableView.loadTags(notes: encrypted)
                self.enableLockedProject()
                self.reloadNotesTable()

                if let indexPath = self.sidebarTableView.getIndexPathBy(project: selectedProject),
                   let sidebarItem = self.sidebarTableView.getSidebarItem(project: selectedProject) {
                    sidebarItem.load(type: .ProjectEncryptedLocked)
                    self.sidebarTableView.reloadRows(at: [indexPath], with: .automatic)
                    self.sidebarTableView.select(project: selectedProject)
                }
            }
        }
    }

    @objc public func decryptProject() {
        guard let selectedProject = searchQuery.project else { return }

        getMasterPassword() { password in
            let decrypted = selectedProject.decrypt(password: password)

            DispatchQueue.main.async {
                guard decrypted.count > 0 else {
                    self.wrongPassAlert()
                    return
                }

                self.sidebarTableView.loadTags(notes: decrypted)
                self.disableLockedProject()
                self.reloadNotesTable()

                if let indexPath = self.sidebarTableView.getIndexPathBy(project: selectedProject),
                   let sidebarItem = self.sidebarTableView.getSidebarItem(project: selectedProject) {
                    sidebarItem.load(type: .Project)
                    self.sidebarTableView.reloadRows(at: [indexPath], with: .automatic)
                    self.sidebarTableView.select(project: selectedProject)
                }
            }
        }
    }

    private func wrongPassAlert() {
        let message = NSLocalizedString("Wrong password", comment: "")
        let alertController = UIAlertController(title: message, message: nil, preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .cancel) { (_) in }
        alertController.addAction(okAction)

        self.present(alertController, animated: true, completion: nil)
    }
}
