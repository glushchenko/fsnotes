//
//  NotesTableView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import MobileCoreServices
import AudioToolbox
import SwipeCellKit
import SSZipArchive

class NotesTableView: UITableView,
    UITableViewDelegate,
    UITableViewDataSource,
    UITableViewDragDelegate,
    SwipeTableViewCellDelegate {

    var notes = [Note]()
    var viewDelegate: ViewController? = nil
    public var selectedIndexPaths: [IndexPath]?

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return calcHeight(indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return calcHeight(indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let note = self.notes[indexPath.row]
            let menu = self.makeBulkMenu(editor: false, note: note)
            return menu
        }
    }

    func tableView(_ tableView: UITableView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        return true
    }

    private func calcHeight(indexPath: IndexPath) -> CGFloat {
        if notes.indices.contains(indexPath.row) {
            let note = notes[indexPath.row]

            if let urls = note.imageUrl, urls.count > 0 {
                if note.preview.count == 0 {
                    if note.getTitle() != nil {

                        // Title + image
                        return 132
                    }

                    // Images only
                    return 120
                }

                // Title + Prevew + Images
                return 160
            }
        }

        return 75
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "noteCell", for: indexPath) as! NoteCellView

        cell.imageKeys = []
        cell.delegate = self

        guard self.notes.indices.contains(indexPath.row) else { return cell }

        let note = self.notes[indexPath.row]

        if !note.isLoaded && !note.isLoadedFromCache {
            note.load()
        }
        
        cell.configure(note: note)
        cell.selectionStyle = .gray
        cell.loadImagesPreview(position: indexPath.row)
        cell.attachHeaders(note: note)

        return cell
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.selectedIndexPaths = self.indexPathsForSelectedRows
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            self.selectedIndexPaths = self.indexPathsForSelectedRows
        }

        guard !self.isEditing, notes.indices.contains(indexPath.row) else { return }

        let note = notes[indexPath.row]
        let evc = UIApplication.getEVC()

        if let editArea = evc.editArea, let u = editArea.undoManager {
            u.removeAllActions()
        }

        if note.container == .encryptedTextPack {
            viewDelegate?.unLock(notes: [note], completion: { notes in
                DispatchQueue.main.async {
                    guard note.container != .encryptedTextPack else {
                        self.askPasswordAndUnlock(note: note, indexPath: indexPath)
                        return
                    }

                    self.reloadRows(notes: [note])
                    NotesTextProcessor.highlight(note: note)

                    self.fill(note: note, indexPath: indexPath)
                }
            })
            
            return
        }

        fill(note: note, indexPath: indexPath)

        if UserDefaultsManagement.autoVersioning && !note.hasGitRepository() {
            DispatchQueue.global().async {
                do {
                    try note.saveRevision()
                } catch {/*_*/}
            }
        }
    }

    private func askPasswordAndUnlock(note: Note, indexPath: IndexPath) {
        self.viewDelegate?.unlockPasswordPrompt(completion: { password in
            self.viewDelegate?.unLock(notes: [note], completion: { success in
                if let success = success, success.count > 0 {
                    self.reloadRows(notes: [note])
                    NotesTextProcessor.highlight(note: note)

                    self.fill(note: note, indexPath: indexPath)
                }
            }, password: password)
        })
    }

    private func askPasswordAndUnEncrypt(note: Note) {
        self.viewDelegate?.unlockPasswordPrompt(completion: { password in
            if note.container == .encryptedTextPack {
                let success = note.unEncrypt(password: password)
                note.password = nil

                if success {
                    DispatchQueue.main.async {
                        UIApplication.getEVC().refill()
                        self.reloadRows(notes: [note], resetKeys: true)
                    }
                }
            }
        })
    }

    private func fill(note: Note, indexPath: IndexPath) {
        UIApplication.getVC().openEditorViewController()
        UIApplication.getEVC().fill(note: note, clearPreview: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.deselectRow(at: indexPath, animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
        var options = SwipeOptions()
        options.transitionStyle = .border
        options.expansionStyle = .selection
        return options
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction]? {
        guard let vc = viewDelegate,
            !UserDefaultsManagement.sidebarIsOpened,
            orientation == .right
        else { return nil }

        let note = self.notes[indexPath.row]

        let deleteTitle = NSLocalizedString("Delete", comment: "Table row action")
        let deleteAction = SwipeAction(style: .destructive, title: deleteTitle) { action, indexPath in
            self.viewDelegate?.sidebarTableView.removeTags(in: [note])
            note.remove()
            self.removeRows(notes: [note])

            if note.isEmpty() {
                vc.storage.removeBy(note: note)
            }
        }
        deleteAction.image = UIImage(systemName: "trash")

        let pinTitle = note.isPinned
            ? NSLocalizedString("Unpin", comment: "Table row action")
            : NSLocalizedString("Pin", comment: "Table row action")

        let pinAction = SwipeAction(style: .default, title: pinTitle) { action, indexPath in
            guard let cell = self.cellForRow(at: indexPath) as? NoteCellView else { return }

            note.togglePin()
            cell.configure(note: note)
            
            let resorted = vc.storage.sortNotes(noteList: self.notes)
            guard let newIndex = resorted.firstIndex(of: note) else { return }

            let newIndexPath = IndexPath(row: newIndex, section: 0)
            self.moveRow(at: indexPath, to: newIndexPath)
            self.notes = resorted

            self.reloadRows(at: [newIndexPath], with: .automatic)
            self.reloadRows(at: [indexPath], with: .automatic)
        }
        pinAction.image = note.isPinned ? UIImage(systemName: "pin.slash") : UIImage(systemName: "pin")
        pinAction.backgroundColor = UIColor(red:0.24, green:0.59, blue:0.94, alpha:1.0)

        let moreTitle = NSLocalizedString("More", comment: "Table row action")
        let moreAction = SwipeAction(style: .default, title: moreTitle) { action, indexPath in
            self.actionsSheet(notes: [note], showAll: true, presentController: self.viewDelegate!)
        }
        moreAction.image = UIImage(systemName: "ellipsis.circle")
        moreAction.backgroundColor = UIColor(red:0.13, green:0.69, blue:0.58, alpha:1.0)

        return [deleteAction, pinAction, moreAction]
    }

    public func turnOffEditing() {
        if self.isEditing {
            self.allowsMultipleSelectionDuringEditing = false
            self.setEditing(false, animated: true)

            deselectAllRows()
        }
    }

    public func getSelectedNotes() -> [Note] {
        var notes = [Note]()

        if let selectedRows = selectedIndexPaths {
            for indexPath in selectedRows {
                if self.notes.indices.contains(indexPath.row) {
                    let note = self.notes[indexPath.row]
                    notes.append(note)
                }
            }

            selectedIndexPaths = nil
        }

        return notes
    }

    public func deselectAllRows() {
        if let selected = indexPathsForSelectedRows {
            for indexP in selected {
                deselectRow(at: indexP, animated: false)
            }
        }
    }

    public func makeBulkMenu(editor: Bool = false, note: Note) -> UIMenu? {
        let handler: (_ action: UIAction) -> () = { action in
            switch action.identifier.rawValue {
            case "cancel":
                break
            case "delete":
                self.removeAction(notes: [note])

                if editor {
                    UIApplication.getEVC().cancel()
                }
            case "calendar":
                self.dateAction(notes: [note])
            case "duplicate":
                self.duplicateAction(notes: [note])
            case "move":
                self.moveAction(notes: [note])
            case "commit":
                self.saveRevisionAction(note: note)
            case "history":
                self.historyAction(note: note)
            case "rename":
                self.renameAction(note: note)
            case "pinUnpin":
                if note.isPinned {
                    note.removePin()
                    self.removePins(notes: [note])
                } else {
                    note.addPin()
                    self.addPins(notes: [note])
                }
            case "lockUnlock":
                self.viewDelegate?.toggleNotesLock(notes: [note])

                if editor {
                    if !note.isUnlocked() {
                        UIApplication.getEVC().cancel()
                    }
                }
            case "removeEncryption":
                self.removeEncryption(note: note)
            case "copy":
                self.copyAction(note: note)
            case "share":
                self.shareAction(note: note)
            case "shareWeb":
                self.shareWebAction(note: note)
            case "deleteWeb":
                self.deleteWebAction(note: note)
            default:
                break
            }

            if ["pinUnpin", "removeEncryption"].contains(action.identifier.rawValue) {
                DispatchQueue.main.async {
                    UIApplication.getEVC().configureNavMenu()
                }
            }

            self.turnOffEditing()
        }

        var actions = [UIAction]()

        let deleteTitle = NSLocalizedString("Delete", comment: "")
        actions.append(UIAction(title: deleteTitle, image: UIImage(systemName: "trash"), identifier: UIAction.Identifier("delete"), attributes: .destructive, handler: handler))

        let calendarTitle = NSLocalizedString("Change Creation Date", comment: "")
        let calendarImage = UIImage(systemName: "calendar")
        actions.append(UIAction(title: calendarTitle, image: calendarImage, identifier: UIAction.Identifier("calendar"), handler: handler))

        let duplicateTitle = NSLocalizedString("Duplicate", comment: "")
        let duplicateImage = UIImage(systemName: "doc.on.doc")
        actions.append(UIAction(title: duplicateTitle, image: duplicateImage, identifier: UIAction.Identifier("duplicate"), handler: handler))

        let moveTitle = NSLocalizedString("Move", comment: "")
        let moveImage = UIImage(systemName: "move.3d")
        actions.append(UIAction(title: moveTitle, image: moveImage, identifier: UIAction.Identifier("move"), handler: handler))


        if note.hasGitRepository() && !note.isEncrypted() {
            let commitTitle = NSLocalizedString("Save Revision", comment: "")
            let commitImage = UIImage(systemName: "plus.circle")
            actions.append(UIAction(title: commitTitle, image: commitImage, identifier: UIAction.Identifier("commit"), handler: handler))
        }

        if UserDefaultsManagement.autoVersioning && !note.isEncrypted() {
            let historyTitle = NSLocalizedString("History", comment: "")
            let historyImage = UIImage(systemName: "clock.arrow.circlepath")
            actions.append(UIAction(title: historyTitle, image: historyImage, identifier: UIAction.Identifier("history"), handler: handler))
        }

        let renameTitle = NSLocalizedString("Rename", comment: "")
        let renameImage = UIImage(systemName: "pencil.circle")
        actions.append(UIAction(title: renameTitle, image: renameImage, identifier: UIAction.Identifier("rename"), handler: handler))

        let pinUnpinTitle = note.isPinned ? NSLocalizedString("Unpin", comment: "") : NSLocalizedString("Pin", comment: "")
        let pinUnpinImage = UIImage(systemName: note.isPinned ? "pin.slash" : "pin")
        actions.append(UIAction(title: pinUnpinTitle, image: pinUnpinImage, identifier: UIAction.Identifier("pinUnpin"), handler: handler))

        let lockUnlockTitle =
            (note.isUnlocked() && note.isEncrypted()) || !note.isEncrypted()
                ? NSLocalizedString("Lock", comment: "")
                : NSLocalizedString("Unlock", comment: "")
        let lockUnlockImageName = (note.isUnlocked() && note.isEncrypted()) || !note.isEncrypted()
            ? "lock"
            : "lock.open"
        let lockUnlockImage = UIImage(systemName: lockUnlockImageName)
        actions.append(UIAction(title: lockUnlockTitle, image: lockUnlockImage, identifier: UIAction.Identifier("lockUnlock"), handler: handler))

        if note.isEncrypted() {
            let removeEncryptionTitle = NSLocalizedString("Remove Encryption", comment: "")
            let removeEncryptionImage = UIImage(systemName: "lock.slash")
            actions.append(UIAction(title: removeEncryptionTitle, image: removeEncryptionImage, identifier: UIAction.Identifier("removeEncryption"), handler: handler))
        }

        var clipboardName = "doc.on.clipboard"
        if #available(iOS 16.0, *) {
            clipboardName = "clipboard"
        }

        let copyTitle = NSLocalizedString("Copy Plain Text", comment: "")
        let copyImage = UIImage(systemName: clipboardName)
        actions.append(UIAction(title: copyTitle, image: copyImage, identifier: UIAction.Identifier("copy"), handler: handler))

        let shareTitle = NSLocalizedString("Share", comment: "")
        let shareImage = UIImage(systemName: "square.and.arrow.up")
        actions.append(UIAction(title: shareTitle, image: shareImage, identifier: UIAction.Identifier("share"), handler: handler))

        let shareWebTitle = NSLocalizedString("Create Web Page", comment: "")
        let shareWebImage = UIImage(systemName: "newspaper")
        actions.append(UIAction(title: shareWebTitle, image: shareWebImage, identifier: UIAction.Identifier("shareWeb"), handler: handler))

        if note.apiId != nil {
            let deleteWebTitle = NSLocalizedString("Delete Web Page", comment: "")
            let deleteWebImage = UIImage(systemName: "newspaper.fill")
            actions.append(UIAction(title: deleteWebTitle, image: deleteWebImage, identifier: UIAction.Identifier("deleteWeb"), handler: handler))
        }

        return UIMenu(title: note.getShortTitle(),  children: actions)
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        setContentOffset(CGPoint(x: 0, y: -44), animated: true)
        return false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        viewDelegate?.navigationItem.hidesSearchBarWhenScrolling = false
        viewDelegate?.navigationItem.largeTitleDisplayMode = .automatic
    }

    public func actionsSheet(notes: [Note], showAll: Bool = false, presentController: UIViewController, back: Bool = false) {
        let note = notes.first!
        let actionSheet = UIAlertController(title: note.project.getFullLabel() + " ➔ " + note.url.lastPathComponent, message: nil, preferredStyle: .actionSheet)

        let remove = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive, handler: { _ in
            self.turnOffEditing()
            self.removeAction(notes: notes)

            if presentController.isKind(of: EditorViewController.self) || back {
                UIApplication.getEVC().cancel()
            }
        })
        remove.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        if let image = UIImage(systemName: "trash")?.resize(maxWidthHeight: 23) {
            remove.setValue(image, forKey: "image")
        }
        actionSheet.addAction(remove)

        if showAll && note.hasGitRepository() && !note.isEncrypted() {
            let history = UIAlertAction(title: NSLocalizedString("Save Revision", comment: ""), style: .default, handler: { _ in
                self.saveRevisionAction(note: notes.first!)
            })
            history.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "plus.circle")?.resize(maxWidthHeight: 23) {
                history.setValue(image, forKey: "image")
            }
            actionSheet.addAction(history)
        }
        
        if showAll && UserDefaultsManagement.autoVersioning && !note.isEncrypted() {
            let history = UIAlertAction(title: NSLocalizedString("History", comment: ""), style: .default, handler: { _ in
                self.historyAction(note: notes.first!)
            })
            history.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: "clock.arrow.circlepath")?.resize(maxWidthHeight: 23) {
                history.setValue(image, forKey: "image")
            }
            actionSheet.addAction(history)
        }

        let creationDate = UIAlertAction(title: NSLocalizedString("Change Creation Date", comment: ""), style: .default, handler: { _ in
            self.dateAction(notes: notes)
        })
        creationDate.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        if let image = UIImage(systemName: "calendar")?.resize(maxWidthHeight: 23) {
            creationDate.setValue(image, forKey: "image")
        }
        actionSheet.addAction(creationDate)

        let duplicate = UIAlertAction(title: NSLocalizedString("Duplicate", comment: ""), style: .default, handler: { _ in
            self.duplicateAction(notes: notes)
        })
        duplicate.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        if let image = UIImage(systemName: "doc.on.doc")?.resize(maxWidthHeight: 23) {
            duplicate.setValue(image, forKey: "image")
        }
        actionSheet.addAction(duplicate)

        if showAll {
            let rename = UIAlertAction(title: NSLocalizedString("Rename", comment: ""), style: .default, handler: { _ in
                self.renameAction(note: note)
            })
            rename.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

            if let image = UIImage(systemName: "pencil.circle")?.resize(maxWidthHeight: 23) {
                rename.setValue(image, forKey: "image")
            }

            actionSheet.addAction(rename)

            let title = note.isPinned ? NSLocalizedString("Unpin", comment: "") : NSLocalizedString("Pin", comment: "")
            let pin = UIAlertAction(title: title, style: .default, handler: { _ in
                if note.isPinned {
                    note.removePin()
                    self.removePins(notes: [note])
                } else {
                    note.addPin()
                    self.addPins(notes: [note])
                }
            })

            pin.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

            if let image = UIImage(systemName: note.isPinned ? "pin.slash" : "pin")?.resize(maxWidthHeight: 23) {
                pin.setValue(image, forKey: "image")
            }

            actionSheet.addAction(pin)
        }

        let move = UIAlertAction(title: NSLocalizedString("Move", comment: ""), style: .default, handler: { _ in
            self.turnOffEditing()
            self.moveAction(notes: notes)
        })
        move.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

        if let image = UIImage(systemName: "move.3d")?.resize(maxWidthHeight: 23) {
            move.setValue(image, forKey: "image")
        }

        actionSheet.addAction(move)

        if showAll {
            let alertTitle =
                (note.isUnlocked() && note.isEncrypted()) || !note.isEncrypted()
                    ? NSLocalizedString("Lock", comment: "")
                    : NSLocalizedString("Unlock", comment: "")

            let imageName = (note.isUnlocked() && note.isEncrypted()) || !note.isEncrypted()
                ? "lock"
                : "lock.open"

            let encryption = UIAlertAction(title: alertTitle, style: .default, handler: { _ in
                self.viewDelegate?.toggleNotesLock(notes: [note])

                if !note.isUnlocked(), presentController.isKind(of: EditorViewController.self) || back {
                    UIApplication.getEVC().cancel()
                }
            })
            encryption.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: imageName)?.resize(maxWidthHeight: 23) {
                encryption.setValue(image, forKey: "image")
            }
            actionSheet.addAction(encryption)

            if note.isEncrypted() {
                let removeEncryption = UIAlertAction(title: NSLocalizedString("Remove Encryption", comment: ""), style: .default, handler: { _ in
                    self.removeEncryption(note: note)
                })

                removeEncryption.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
                if let image = UIImage(systemName: "lock.slash")?.resize(maxWidthHeight: 23) {
                    removeEncryption.setValue(image, forKey: "image")
                }

                actionSheet.addAction(removeEncryption)
            }

            var clipboardName = "doc.on.clipboard"
            if #available(iOS 16.0, *) {
                clipboardName = "clipboard"
            }

            let copy = UIAlertAction(title: NSLocalizedString("Copy Plain Text", comment: ""), style: .default, handler: { _ in
                self.copyAction(note: note)
            })
            copy.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(systemName: clipboardName)?.resize(maxWidthHeight: 23) {
                copy.setValue(image, forKey: "image")
            }
            actionSheet.addAction(copy)

            let share = UIAlertAction(title: NSLocalizedString("Share", comment: ""), style: .default, handler: { _ in
                self.shareAction(note: note)
            })
            share.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

            if let image = UIImage(systemName: "square.and.arrow.up")?.resize(maxWidthHeight: 23) {
                share.setValue(image, forKey: "image")
            }

            actionSheet.addAction(share)
        }

        let dismiss = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { _ in
            if self.isEditing {
                self.setEditing(false, animated: true)
            }
        })
        actionSheet.addAction(dismiss)

        if let view = UIApplication.getEVC().view {
            actionSheet.popoverPresentationController?.sourceView = view
            actionSheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.size.width / 2.0, y: view.bounds.size.height, width: 2.0, height: 1.0)
        }

        presentController.present(actionSheet, animated: true, completion: nil)
    }
    
    public func removeRows(notes: [Note]) {
        guard notes.count > 0, let vc = viewDelegate, vc.isNoteInsertionAllowed() else { return }

        vc.removeSpotlightIndex(notes: notes)

        var indexPaths = [IndexPath]()
        var tags = [String]()
        for note in notes {
            if let i = self.notes.firstIndex(where: {$0 === note}) {
                indexPaths.append(IndexPath(row: i, section: 0))
                tags.append(contentsOf: note.tags)
            }
        }

        self.notes.removeAll(where: { notes.contains($0) })

        deleteRows(at: indexPaths, with: .automatic)
        vc.updateNotesCounter()

        vc.sidebarTableView.delete(tags: tags)
    }

    public func insertRows(notes: [Note]) {
        guard notes.count > 0, let vc = viewDelegate, vc.isNoteInsertionAllowed() else { return }
        vc.storage.loadPins(notes: notes)

        var toInsert = [Note]()

        for note in notes {
            guard vc.storage.searchQuery.isFit(note: note),
                !self.notes.contains(where: {$0 === note})
            else { continue }

            toInsert.append(note)
        }

        guard toInsert.count > 0 else { return }
        vc.updateSpotlightIndex(notes: toInsert)

        let nonSorted = self.notes + toInsert
        let sorted = vc.storage.sortNotes(noteList: nonSorted)

        var indexPaths = [IndexPath]()
        for note in toInsert {
            guard let index = sorted.firstIndex(of: note) else { continue }
            indexPaths.append(IndexPath(row: index, section: 0))
        }

        self.notes = sorted

        insertRows(at: indexPaths, with: .fade)
        reloadRows(notes: notes, resetKeys: true)
    }

    public func reloadRows(notes: [Note], resetKeys: Bool = false) {
        beginUpdates()
        for note in notes {
            if let i = self.notes.firstIndex(where: {$0 === note}) {
                let indexPath = IndexPath(row: i, section: 0)
                if let cell = cellForRow(at: indexPath) as? NoteCellView {
                    if resetKeys {
                        cell.imageKeys = []
                    }

                    cell.configure(note: note)
                    cell.updateView()
                }
            }
        }
        endUpdates()

        viewDelegate?.updateSpotlightIndex(notes: notes)
    }
    
    public func reloadRowForce(note: Note) {
        note.invalidateCache()
        note.loadPreviewInfo()
        
        if let index = notes.firstIndex(of: note) {
            reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
    }

    private func renameAction(note: Note) {
        let alertController = UIAlertController(title: NSLocalizedString("Rename note:", comment: ""), message: nil, preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            [] (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Enter note name", comment: "")
            textField.attributedText = NSAttributedString(string: note.getFileName())
        })

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            self.rename(note: note, to: name)
        }

        let title = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: title, style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        UIApplication.getNC()?.present(alertController, animated: true) {
            alertController.textFields![0].selectAll(nil)
        }
    }

    public func rename(note: Note, to name: String) {

        guard name.count > 0, name.trim().count > 0 else { return }

        var name = name
        var i = 1

        
        while note.project.fileExistCaseInsensitive(fileName: name, ext: note.url.pathExtension) {

            // disables renaming loop
            if note.fileName.startsWith(string: name) {
                return
            }
            
            let items = name.split(separator: " ")

            if let last = items.last, let position = Int(last) {
                let full = items.dropLast()

                name = full.joined(separator: " ") + " " + String(position + 1)

                i = position + 1
            } else {
                name = name + " " + String(i)

                i += 1
            }
        }

        let isPinned = note.isPinned
        let dst = note.getNewURL(name: name)
        let src = note.url

        note.removePin()

        if note.isEncrypted() {
            _ = note.lock()
        }

        if note.move(to: dst) {
            note.url = dst
            note.parseURL()
            
            note.moveHistory(src: src, dst: dst)
        }

        if isPinned {
            note.addPin()
        }

        DispatchQueue.main.async {
            self.reloadRows(notes: [note])
        }
    }

    public func removeAction(notes: [Note]) {
        guard let vc = viewDelegate else { return }

        vc.sidebarTableView.removeTags(in: notes)
        for note in notes {
            note.remove()
        }
        removeRows(notes: notes)

        allowsMultipleSelectionDuringEditing = false
        setEditing(false, animated: true)
    }

    public func moveAction(notes: [Note]) {
        let moveController = MoveViewController(notes: notes, notesTableView: self)
        let controller = UINavigationController(rootViewController: moveController)

        let nvc = UIApplication.getNC()
        nvc?.present(controller, animated: true, completion: nil)
    }

    public func dateAction(notes: [Note]) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let datePickerViewController = storyBoard.instantiateViewController(withIdentifier: "datePickerViewController") as! DatePickerViewController
        datePickerViewController.notes = notes

        let nvc = UIApplication.getNC()
        nvc?.present(datePickerViewController, animated: true )
    }

    public func showLoader() {
        let title = NSLocalizedString("Loading...", comment: "")
        let alert = UIAlertController(title: nil, message: title, preferredStyle: .alert)

        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium
        loadingIndicator.startAnimating();

        alert.view.addSubview(loadingIndicator)

        UIApplication.getNC()?.present(alert, animated: true)
    }

    public func hideLoader() {
        DispatchQueue.main.async {
            UIApplication.getNC()?.dismiss(animated: false, completion: nil)
        }
    }

    public func saveRevisionAction(note: Note? = nil, project: Project? = nil) {
        var current: Project?

        if let unwrappedProject = project {
            current = unwrappedProject
        } else if let note = note {
            current = note.getGitProject()
        }

        guard let project = current else { return }
        guard let nvc = UIApplication.getNC() else { return }

        let viewController = UIApplication.getVC()

        // Show loader
        let title = NSLocalizedString("Loading...", comment: "")
        let alert = UIAlertController(title: nil, message: title, preferredStyle: .alert)

        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium
        loadingIndicator.startAnimating();

        alert.view.addSubview(loadingIndicator)
        nvc.present(alert, animated: true)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try project.saveRevision()

                // Hide loader
                DispatchQueue.main.async {
                    nvc.dismiss(animated: false, completion: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    // Hide loader
                    nvc.dismiss(animated: false, completion: nil)

                    project.gitStatus = error.localizedDescription

                    let alert = UIAlertController(title: "Git error", message: error.localizedDescription, preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

                    nvc.present(alert, animated: true, completion: nil)
                }

                return
            }

            if project.isGitOriginExist() {
                viewController.gitQueue.addOperation({
                    try? project.pull()
                    try? project.push()
                })
            }
        }
    }

    private func historyAction(note: Note) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let datePickerViewController = storyBoard.instantiateViewController(withIdentifier: "revisionsViewController") as! RevisionsViewController
        datePickerViewController.note = note

        UIApplication.getNC()?.present(datePickerViewController, animated: true)
    }

    private func copyAction(note: Note) {
        let item = [kUTTypeUTF8PlainText as String : note.content.string as Any]

        UIPasteboard.general.items = [item]
    }

    public func shareAction(note: Note, isHTML: Bool = false) {
        AudioServicesPlaySystemSound(1519)

        var tempURL = note.url
        if note.isTextBundle() {
            tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(note.getName()).zip")
            SSZipArchive.createZipFile(atPath: tempURL.path, withContentsOfDirectory: note.url.path, keepParentDirectory: true)
        }

        let objectsToShare = [tempURL] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        activityVC.excludedActivityTypes = [ UIActivity.ActivityType.addToReadingList ]

        guard let presentController = UIApplication.getNC() else { return }
        presentController.present(activityVC, animated: true, completion: nil)

        guard let popOver = activityVC.popoverPresentationController else { return }
        popOver.permittedArrowDirections = .up

        let notesTable = UIApplication.getVC().notesTable
        let editorView = UIApplication.getEVC().editArea

        if let topViewController = presentController.topViewController {
            if topViewController.isKind(of: EditorViewController.self) {
                popOver.sourceView = editorView
                popOver.sourceRect = CGRect(x: editorView!.bounds.midX, y: 80, width: 0, height: 0)

            } else if topViewController.isKind(of: ViewController.self),
                let i = notesTable?.notes.firstIndex(where: {$0 === note}),
                let rowView = notesTable?.cellForRow(at: IndexPath(row: i, section: 0)) {

                popOver.sourceView = rowView
                popOver.sourceRect = CGRect(x: notesTable!.bounds.midX, y: rowView.frame.height, width: 10, height: 10)
            }
        }
    }

    public func duplicateAction(notes: [Note]) {
        var dupes = [Note]()
        for note in notes {
            let src = note.url
            let dst = NameHelper.generateCopy(file: note.url)

            if note.isTextBundle() || note.isEncrypted() {
                try? FileManager.default.copyItem(at: src, to: dst)

                let noteDupe = Note(url: dst, with: note.project)
                noteDupe.load()

                viewDelegate?.storage.add(noteDupe)
                dupes.append(noteDupe)
                continue
            }

            let name = dst.deletingPathExtension().lastPathComponent
            let noteDupe = Note(name: name, project: note.project, type: note.type, cont: note.container)
            noteDupe.content = NSMutableAttributedString(string: note.content.string)

            // Clone images
            if note.type == .Markdown && note.container == .none {
                let images = note.getAllImages()
                for image in images {
                    noteDupe.move(from: image.url, imagePath: image.path, to: note.project, copy: true)
                }
            }

            noteDupe.save()

            viewDelegate?.storage.add(noteDupe)
            dupes.append(noteDupe)
        }

        insertRows(notes: dupes)

        if let scrollTo = dupes.first {
            viewDelegate?.notesTable.scrollTo(note: scrollTo)
        }
    }

    private func decryptUnlocked(notes: [Note]) -> [Note] {
        var notes = notes
        var toReload = [Note]()

        for note in notes {
            if note.isUnlocked() {
                if note.unEncryptUnlocked() {
                    notes.removeAll { $0 === note }
                    toReload.append(note)
                    note.invalidateCache()
                }
            }
        }

        DispatchQueue.main.async {
            self.reloadRows(notes: toReload, resetKeys: true)
        }

        return notes
    }

    public func removeEncryption(note: Note) {
        let vc = UIApplication.getVC()

        let notes = decryptUnlocked(notes: [note])
        guard let note = notes.first else { return }

        vc.getMasterPassword() { password in
            if note.container == .encryptedTextPack {
                let success = note.unEncrypt(password: password)
                note.password = nil

                if success {
                    DispatchQueue.main.async {
                        UIApplication.getEVC().refill()
                    }
                } else {
                    self.askPasswordAndUnEncrypt(note: note)
                    return
                }
            }

            DispatchQueue.main.async {
                self.reloadRows(notes: notes, resetKeys: true)
            }
        }
    }

    public func shareWebAction(note: Note) {
        UIApplication.getVC().createAPI(note: note, completion: { url in
            DispatchQueue.main.async {
                self.reloadRowForce(note: note)

                if let url = url {
                    UIApplication.shared.open(url)
                }

                UIApplication.getEVC().configureNavMenu()
            }
        })
    }

    public func deleteWebAction(note: Note) {
        UIApplication.getVC().deleteAPI(note: note, completion: {
            DispatchQueue.main.async {
                self.reloadRowForce(note: note)

                UIApplication.getEVC().configureNavMenu()
            }
        })
    }

    public func moveRowUp(note: Note) {
        guard let vc = viewDelegate,
            vc.isNoteInsertionAllowed(),
            vc.storage.searchQuery.isFit(note: note),
            let at = notes.firstIndex(where: {$0 === note})
        else { return }

        var to = 0

        let sorted = vc.storage.sortNotes(noteList: notes)
        to = sorted.firstIndex(of: note) ?? at

        let atIndexPath = IndexPath(row: at, section: 0)
        let toIndexPath = IndexPath(row: to, section: 0)

        if at != to {
            let note = notes.remove(at: at)
            notes.insert(note, at: to)
            moveRow(at: atIndexPath, to: toIndexPath)
        }

        if atIndexPath != toIndexPath {
            reloadRows(at: [atIndexPath, toIndexPath], with: .automatic)
        }

        // scroll to hack
        // https://stackoverflow.com/questions/26244293/scrolltorowatindexpath-with-uitableview-does-not-work
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        //            if note.project.sortBy == .modificationDate, let first = self.notes.first {
        //                self.scrollTo(note: first)
        //            } else {
        //                self.scrollTo(note: note)
        //            }
        //        }
    }

    @objc public func toggleSelectAll() {
        guard self.isEditing else { return }

        if let selected = self.indexPathsForSelectedRows, (selected.count - 1) == self.notes.count {
            for indexPath in selected {
                self.deselectRow(at: indexPath, animated: false)
            }

            self.selectedIndexPaths = nil
        } else {
            for i in 0...notes.count {
                self.selectRow(at: IndexPath(item: i, section: 0), animated: false, scrollPosition: .none)
            }

            self.selectedIndexPaths = indexPathsForSelectedRows
        }
    }

    private func invalidPasswordAlert() {
        let invalid = NSLocalizedString("Invalid Password", comment: "")
        let message = NSLocalizedString("Please enter valid password", comment: "")
        let alert = UIAlertController(title: invalid, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

        UIApplication.getVC().present(alert, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {

        guard let cell = tableView.cellForRow(at: indexPath) as? NoteCellView,
            let url = cell.note?.url
        else { return [] }

        let itemProvider = NSItemProvider(item: url as NSSecureCoding, typeIdentifier: kUTTypeURL as String)

        return [UIDragItem(itemProvider: itemProvider)]
    }

    public func addPins(notes: [Note]) {
        guard let vc = viewDelegate else { return }
        for note in notes {
            let sorted = vc.storage.sortNotes(noteList: self.notes)

            if let index = self.notes.firstIndex(of: note), let toIndex = sorted.firstIndex(of: note) {

                let note = self.notes.remove(at: index)
                self.notes.insert(note, at: toIndex)

                let at = IndexPath(row: index, section: 0)
                let to = IndexPath(row: toIndex, section: 0)

                moveRow(at: at, to: to)

                let reload = [
                    IndexPath(row: index, section: 0),
                    IndexPath(row: toIndex, section: 0)
                ]

                reloadRows(at: reload, with: .automatic)
            }
        }
    }

    public func removePins(notes: [Note]) {
        guard let vc = viewDelegate else { return }
        for note in notes {
            let sorted = vc.storage.sortNotes(noteList: self.notes)

            if let index = self.notes.firstIndex(of: note), let toIndex = sorted.firstIndex(of: note) {

                let note = self.notes.remove(at: index)
                self.notes.insert(note, at: toIndex)

                let at = IndexPath(row: index, section: 0)
                let to = IndexPath(row: toIndex, section: 0)

                moveRow(at: at, to: to)

                let reload = [
                    IndexPath(row: index, section: 0),
                    IndexPath(row: toIndex, section: 0)
                ]

                reloadRows(at: reload, with: .automatic)
            }
        }
    }

    public func scrollTo(note: Note) {
        if let index = notes.firstIndex(of: note) {
            let indexPath = IndexPath(row: index, section: 0)
            scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }
    
    public func doVisualChanges(results: ([Note], [Note], [Note])) {
        guard results.0.count > 0 || results.1.count > 0 || results.2.count > 0 else {
            return
        }
        
        DispatchQueue.main.async {
            self.removeRows(notes: results.0)
            self.insertRows(notes: results.1)
            self.reloadRows(notes: results.2)
        }
    }
}
