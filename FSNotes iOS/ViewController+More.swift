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
        let project = sidebarItem.project
        let handler: (_ action: UIAction) -> () = { action in

        switch action.identifier.rawValue {
            case "emptyBin":
                self.emptyBin()
            case "importNote":
                self.importNote(selectedProject: project)
            case "viewSettings":
                self.openProjectSettings(sidebarItem: sidebarItem)
            case "gitSettings":
                self.openGitSettings(selectedProject: project)
            case "bulkEditing":
                self.bulkEditing()
            case "createFolder":
                self.createFolder(selectedProject: project)
            case "removeFolder":
                self.removeFolder(selectedProject: project)
            case "renameFolder":
                self.renameFolder(selectedProject: project)
            case "removeTag":
                self.removeTag(sidebarItem: sidebarItem)
            case "renameTag":
                self.renameTag(sidebarItem: sidebarItem)
            case "openInFiles":
                self.openInFiles(selectedProject: project)
            case "lockFolder":
                self.lockProject(selectedProject: project)
            case "unlockFolder":
                self.unlockProject(selectedProject: project)
            case "decryptFolder":
                self.decryptProject(selectedProject: project)
            case "encryptFolder":
                self.encryptProject(selectedProject: project)
            case "gitAddCommitPush":
                self.addCommitPush(selectedProject: project)
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
            let title = NSLocalizedString("Remove Folder", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "trash"), identifier: UIAction.Identifier("removeFolder"), attributes: .destructive, handler: handler))
        }

        if popoverActions.contains(.emptyBin) {
            let title = NSLocalizedString("Empty Bin", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "xmark.circle"), identifier: UIAction.Identifier("emptyBin"), handler: handler))
        }

        if popoverActions.contains(.importNote) {
            let title = NSLocalizedString("Import Notes", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "square.and.arrow.down"), identifier: UIAction.Identifier("importNote"), handler: handler))
        }

        if popoverActions.contains(.settingsFolder) {
            let title = NSLocalizedString("View Settings", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "gearshape"), identifier: UIAction.Identifier("viewSettings"), handler: handler))
        }

        if popoverActions.contains(.settingsRepository) {
            let title = NSLocalizedString("Git Settings", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(named: "gitSettings"), identifier: UIAction.Identifier("gitSettings"), handler: handler))

            if let project = sidebarItem.project, project.getGitProject() != nil {
                let titleAddCommit = NSLocalizedString("Git Add/commit/push", comment: "Main view popover table")
                actions.append(UIAction(title: titleAddCommit, image: UIImage(systemName: "plus.circle"), identifier: UIAction.Identifier("gitAddCommitPush"), handler: handler))
            }
        }

        if popoverActions.contains(.multipleSelection) {
            let title = NSLocalizedString("Select", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "checkmark.circle"), identifier: UIAction.Identifier("bulkEditing"), handler: handler))
        }

        if popoverActions.contains(.createFolder) {
            let title = NSLocalizedString("Create Folder", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "folder.badge.plus"), identifier: UIAction.Identifier("createFolder"), handler: handler))
        }

        if popoverActions.contains(.renameFolder) {
            let title = NSLocalizedString("Rename Folder", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "pencil.circle"), identifier: UIAction.Identifier("renameFolder"), handler: handler))
        }

        if popoverActions.contains(.removeTag) {
            let title = NSLocalizedString("Remove Tag", comment: "Main view popover table")
            actions.append(UIAction(title: title, image: UIImage(systemName: "tag.slash"), identifier: UIAction.Identifier("removeTag"), handler: handler))
        }

        if popoverActions.contains(.renameTag) {
            let title = NSLocalizedString("Rename Tag", comment: "Main view popover table")
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

        if let tag = Storage.shared().searchQuery.tags.first {
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
            let title = NSLocalizedString("Remove Folder", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .destructive, handler: { _ in
                self.removeFolder(selectedProject: sidebarItem?.project)
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
            let title = NSLocalizedString("Import Notes", comment: "Main view popover table")
            let importNote = UIAlertAction(title:title, style: .default, handler: { _ in
                self.importNote(selectedProject: sidebarItem?.project)
            })
            importNote.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

            if let image = UIImage(systemName: "square.and.arrow.down")?.resize(maxWidthHeight: 23) {
                importNote.setValue(image, forKey: "image")
            }

            actionSheet.addAction(importNote)
        }

        if actions.contains(.settingsFolder) {
            let title = NSLocalizedString("View Settings", comment: "Main view popover table")
            let settings = UIAlertAction(title:title, style: .default, handler: { _ in
                self.openProjectSettings(sidebarItem: sidebarItem)
            })
            settings.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "gearshape")?.resize(maxWidthHeight: 23) {
                settings.setValue(image, forKey: "image")
            }
            actionSheet.addAction(settings)
        }

        if actions.contains(.settingsRepository) {
            let title = NSLocalizedString("Git Settings", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.openGitSettings(selectedProject: sidebarItem?.project)
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
            let title = NSLocalizedString("Create Folder", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.createFolder(selectedProject: sidebarItem?.project)
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "folder.badge.plus")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.renameFolder) {
            let title = NSLocalizedString("Rename Folder", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.renameFolder(selectedProject: sidebarItem?.project)
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "pencil.circle")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.removeTag) {
            let title = NSLocalizedString("Remove Tag", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .destructive, handler: { _ in
                self.removeTag(sidebarItem: sidebarItem)
            })
            alertAction.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "tag.slash")?.resize(maxWidthHeight: 23) {
                alertAction.setValue(image, forKey: "image")
            }
            actionSheet.addAction(alertAction)
        }

        if actions.contains(.renameTag) {
            let title = NSLocalizedString("Rename Tag", comment: "Main view popover table")
            let alertAction = UIAlertAction(title:title, style: .default, handler: { _ in
                self.renameTag(sidebarItem: sidebarItem)
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
                self.openInFiles(selectedProject: sidebarItem?.project)
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
                self.lockProject(selectedProject: sidebarItem?.project)
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
                self.unlockProject(selectedProject: sidebarItem?.project)
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
                self.decryptProject(selectedProject: sidebarItem?.project)
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
                self.encryptProject(selectedProject: sidebarItem?.project)
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
        guard let projectURL = selectedProject?.url else { return }

        for url in urls {
            let dstURL = projectURL.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dstURL)
        }

        self.dismiss(animated: true, completion: nil)
    }

    private func importNote(selectedProject: Project?) {
        self.selectedProject = selectedProject

        let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }

    public func openProjectSettings(sidebarItem: SidebarItem?) {
        let vc = UIApplication.getVC()
        let storage = Storage.shared()

        // All projects

        var currentProject = sidebarItem?.project
        if currentProject == nil {
            currentProject = storage.getCurrentProject()
        }

        // Virtual projects Notes and Todo

        if sidebarItem?.type == .Todo || sidebarItem?.type == .All {
            currentProject = sidebarItem?.project
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

            // load navbar
            
            let cancelTitle = NSLocalizedString("Cancel", comment: "")
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: cancelTitle, style: .plain, target: self, action: #selector(cancel))

            // load toolbar

            let deleteImage = UIImage(systemName: "trash")
            let calendarImage = UIImage(systemName: "calendar")
            let duplicateImage = UIImage(systemName: "doc.on.doc")
            let moveImage = UIImage(systemName: "move.3d")

            if #available(iOS 14.0, *) {
                var items = [UIBarButtonItem]()
                items.append(UIBarButtonItem(image: deleteImage, style: .plain, target: self, action: #selector(removeNotes)))
                items.append(UIBarButtonItem.flexibleSpace())
                items.append(UIBarButtonItem(image: calendarImage, style: .plain, target: self, action: #selector(calendarNotes)))
                items.append(UIBarButtonItem.flexibleSpace())
                items.append(UIBarButtonItem(image: duplicateImage, style: .plain, target: self, action: #selector(duplicateNotes)))
                items.append(UIBarButtonItem.flexibleSpace())
                items.append(UIBarButtonItem(image: moveImage, style: .plain, target: self, action: #selector(moveNotes)))
                toolbarItems = items

                hideNewButton()
            }

            navigationController?.toolbar.tintColor = UIColor.mainTheme
            navigationController?.setToolbarHidden(false, animated: true)
            navigationController?.navigationBar.tintColor = UIColor.mainTheme
        }
    }

    public func hideNewButton() {
        getButton(tag: 1)?.isHidden = true
    }

    public func showNewButton() {
        getButton(tag: 1)?.isHidden = false
    }

    public func configureSidebarNavMenu() {
        if let sidebarItem = UIApplication.getVC().lastSidebarItem {
            configureNavMenu(for: sidebarItem)
        }
    }
    
    @objc func removeNotes() {
        let notes = notesTable.getSelectedNotes()
        notesTable.removeAction(notes: notes)
        notesTable.turnOffEditing()

        configureSidebarNavMenu()
        showNewButton()

        navigationController?.setToolbarHidden(true, animated: true)
    }

    @objc func calendarNotes() {
        let notes = notesTable.getSelectedNotes()
        notesTable.dateAction(notes: notes)
        notesTable.turnOffEditing()

        configureSidebarNavMenu()
        showNewButton()

        navigationController?.setToolbarHidden(true, animated: true)
    }

    @objc func duplicateNotes() {
        let notes = notesTable.getSelectedNotes()
        notesTable.duplicateAction(notes: notes)
        notesTable.turnOffEditing()

        configureSidebarNavMenu()
        showNewButton()

        navigationController?.setToolbarHidden(true, animated: true)
    }

    @objc func moveNotes() {
        let notes = notesTable.getSelectedNotes()
        notesTable.moveAction(notes: notes)
        notesTable.turnOffEditing()

        configureSidebarNavMenu()
        showNewButton()

        navigationController?.setToolbarHidden(true, animated: true)
    }

    @objc func cancel() {
        notesTable.turnOffEditing()

        configureSidebarNavMenu()

        navigationController?.setToolbarHidden(true, animated: true)

        showNewButton()
    }

    private func createFolder(selectedProject: Project?) {
        guard let selectedProject = selectedProject else { return }

        let mvc = UIApplication.getVC()
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

            if let projects = Storage.shared().insert(url: newDir) {
                OperationQueue.main.addOperation {
                    UIApplication.getVC().sidebarTableView.insertRows(projects: projects)
                }
            }
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

    private func removeFolder(selectedProject: Project?) {
        guard let selectedProject = selectedProject else { return }
        guard !selectedProject.isDefault else { return }

        let mvc = UIApplication.getVC()
        let alert = UIAlertController(
            title: "Folder removing 🚨",
            message: "Are you really want to remove \"\(selectedProject.label)\"? Folder content will be deleted, action can not be undone.",
            preferredStyle: UIAlertController.Style.alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction!) in
            OperationQueue.main.addOperation {
                mvc.sidebarTableView.removeRows(projects: [selectedProject])

                if !selectedProject.isBookmark {
                    try? FileManager.default.removeItem(at: selectedProject.url)
                }

                Storage.shared().remove(project: selectedProject)
            }
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
        }))

        if selectedProject.isBookmark {
            OperationQueue.main.addOperation {
                let bookmark = SandboxBookmark.sharedInstance()
                bookmark.remove(url: selectedProject.url)

                mvc.sidebarTableView.removeRows(projects: [selectedProject])
            }
        } else {
            mvc.present(alert, animated: true, completion: nil)
        }
    }

    private func renameFolder(selectedProject: Project?) {
        guard let selectedProject = selectedProject else { return }

        let mvc = UIApplication.getVC()
        let title = NSLocalizedString("Rename folder:", comment: "Popover table")
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            [] (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Enter folder name", comment: "")
            textField.text = selectedProject.url.lastPathComponent
        })

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            OperationQueue.main.addOperation {
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

                if let projects = self.storage.insert(url: newDir) {
                    mvc.sidebarTableView.insertRows(projects: projects)
                    
                    if let first = projects.first {
                        mvc.sidebarTableView.select(project: first)
                    }
                }
            }
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

    private func removeTag(sidebarItem: SidebarItem?) {
        let mvc = UIApplication.getVC()

        guard let sidebarItem = sidebarItem, sidebarItem.type == .Tag else { return }
        guard let selectedProject = mvc.storage.searchQuery.projects.first else { return }

        let tag = sidebarItem.name

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

    private func renameTag(sidebarItem: SidebarItem?) {
        let mvc = UIApplication.getVC()

        guard let sidebarItem = sidebarItem, sidebarItem.type == .Tag else { return }
        guard let selectedProject = mvc.storage.searchQuery.projects.first else { return }

        let tag = sidebarItem.name

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

    private func openInFiles(selectedProject: Project?) {
        guard let selectedProject = selectedProject else { return }

        let mvc = UIApplication.getVC()

        guard let path = selectedProject.url.path.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed) else { return }

        if let projectUrl = URL(string: "shareddocuments://" + path) {
            UIApplication.shared.open(projectUrl, options: [:])
        }
    }

    private func openGitSettings(selectedProject: Project?) {
        guard let selectedProject = selectedProject else { return }

        let vc = UIApplication.getVC()
        let storage = Storage.shared()
        let projectController = AppDelegate.getGitVC(for: selectedProject)
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

    @objc public func unlock() {
        guard let project = sidebarTableView.getSelectedSidebarItem()?.project else { return }

        unlockProject(selectedProject: project)
    }

    public func unlockProject(selectedProject: Project?, createNote: Bool = false) {
        guard let selectedProject = selectedProject else { return }

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
                self.configureSidebarNavMenu()
            }
        }
    }

    public func lockProject(selectedProject: Project?) {
        guard let selectedProject = selectedProject else { return }

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
            
            self.configureSidebarNavMenu()
        }
    }

    public func encryptProject(selectedProject: Project?) {
        guard let selectedProject = selectedProject else { return }

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

    public func addCommitPush(selectedProject: Project?) {
        guard let selectedProject = selectedProject?.getGitProject() else { return }

        notesTable.saveRevisionAction(project: selectedProject)
    }

    public func decryptProject(selectedProject: Project?) {
        guard let selectedProject = selectedProject else { return }

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
