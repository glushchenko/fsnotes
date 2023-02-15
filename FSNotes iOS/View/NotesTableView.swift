//
//  NotesTableView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight
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

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

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
                        self.invalidPasswordAlert()
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

        if UserDefaultsManagement.autoVersioning && !UserDefaultsManagement.gitVersioning {
            DispatchQueue.global().async {
                do {
                    try note.saveRevision()
                } catch {/*_*/}
            }
        }
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
        deleteAction.image = UIImage(named: "basket")?.resize(maxWidthHeight: 32)

        let pinTitle = note.isPinned
            ? NSLocalizedString("UnPin", comment: "Table row action")
            : NSLocalizedString("Pin", comment: "Table row action")

        let pinAction = SwipeAction(style: .default, title: pinTitle) { action, indexPath in
            guard let cell = self.cellForRow(at: indexPath) as? NoteCellView else { return }

            note.togglePin()
            cell.configure(note: note)

            let filter = vc.navigationItem.searchController?.searchBar.text ?? ""

            let project = self.viewDelegate?.sidebarTableView.getSidebarProjects()?.first
            let resorted = vc.storage.sortNotes(noteList: self.notes, filter: filter, project: project)
            
            guard let newIndex = resorted.firstIndex(of: note) else { return }

            let newIndexPath = IndexPath(row: newIndex, section: 0)
            self.moveRow(at: indexPath, to: newIndexPath)
            self.notes = resorted

            self.reloadRows(at: [newIndexPath], with: .automatic)
            self.reloadRows(at: [indexPath], with: .automatic)
        }
        pinAction.image = UIImage(named: "pin_row_action")?.resize(maxWidthHeight: 32)
        pinAction.backgroundColor = UIColor(red:0.24, green:0.59, blue:0.94, alpha:1.0)

        let moreTitle = NSLocalizedString("More", comment: "Table row action")
        let moreAction = SwipeAction(style: .default, title: moreTitle) { action, indexPath in
            self.actionsSheet(notes: [note], showAll: true, presentController: self.viewDelegate!)
        }
        moreAction.image = UIImage(named: "more_row_action")?.resize(maxWidthHeight: 32)
        moreAction.backgroundColor = UIColor(red:0.13, green:0.69, blue:0.58, alpha:1.0)

        return [moreAction, pinAction, deleteAction]
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }

    public func turnOffEditing() {
        if self.isEditing {
            self.allowsMultipleSelectionDuringEditing = false
            self.setEditing(false, animated: true)
        }
    }

    public func actionsSheet(notes: [Note], showAll: Bool = false, presentController: UIViewController, back: Bool = false) {
        let note = notes.first!
        let actionSheet = UIAlertController(title: note.project.getFullLabel() + " ➔ " + note.url.lastPathComponent, message: nil, preferredStyle: .actionSheet)

        let remove = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive, handler: { _ in
            self.turnOffEditing()
            self.removeAction(notes: notes, presentController: presentController)

            if presentController.isKind(of: EditorViewController.self) || back {
                UIApplication.getEVC().cancel()
            }
        })
        remove.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        if let image = UIImage(named: "removeAction")?.resize(maxWidthHeight: 22) {
            remove.setValue(image, forKey: "image")
        }
        actionSheet.addAction(remove)

        if showAll && UserDefaultsManagement.autoVersioning && !note.isEncrypted() {
            let history = UIAlertAction(title: NSLocalizedString("History", comment: ""), style: .default, handler: { _ in
                self.historyAction(note: notes.first!, presentController: presentController)
            })
            history.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "historyAction")?.resize(maxWidthHeight: 25) {
                history.setValue(image, forKey: "image")
            }
            actionSheet.addAction(history)
        }

        let creationDate = UIAlertAction(title: NSLocalizedString("Date created", comment: ""), style: .default, handler: { _ in
            self.dateAction(notes: notes, presentController: presentController)
        })
        creationDate.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        if let image = UIImage(named: "dateAction")?.resize(maxWidthHeight: 25) {
            creationDate.setValue(image, forKey: "image")
        }
        actionSheet.addAction(creationDate)

        let duplicate = UIAlertAction(title: NSLocalizedString("Duplicate", comment: ""), style: .default, handler: { _ in
            self.duplicateAction(notes: notes, presentController: presentController)
        })
        duplicate.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
        if let image = UIImage(named: "duplicateAction")?.resize(maxWidthHeight: 22) {
            duplicate.setValue(image, forKey: "image")
        }
        actionSheet.addAction(duplicate)

        if showAll {
            let rename = UIAlertAction(title: NSLocalizedString("Rename", comment: ""), style: .default, handler: { _ in
                self.renameAction(note: note, presentController: presentController)
            })
            rename.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

            if let image = UIImage(named: "renameAction")?.resize(maxWidthHeight: 23) {
                rename.setValue(image, forKey: "image")
            }

            actionSheet.addAction(rename)

            let title = note.isPinned ? NSLocalizedString("UnPin", comment: "") : NSLocalizedString("Pin", comment: "")
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

            if let image = UIImage(named: "pinAction")?.resize(maxWidthHeight: 23) {
                pin.setValue(image, forKey: "image")
            }

            actionSheet.addAction(pin)
        }

        let move = UIAlertAction(title: NSLocalizedString("Move", comment: ""), style: .default, handler: { _ in
            self.turnOffEditing()
            self.moveAction(notes: notes, presentController: presentController)
        })
        move.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

        if let image = UIImage(named: "moveAction")?.resize(maxWidthHeight: 23) {
            move.setValue(image, forKey: "image")
        }

        actionSheet.addAction(move)

        if showAll {
            let alertTitle =
                (note.isUnlocked() && note.isEncrypted()) || !note.isEncrypted()
                    ? NSLocalizedString("Lock", comment: "")
                    : NSLocalizedString("Unlock", comment: "")

            let encryption = UIAlertAction(title: alertTitle, style: .default, handler: { _ in
                self.viewDelegate?.toggleNotesLock(notes: [note])

                if !note.isUnlocked(), presentController.isKind(of: EditorViewController.self) || back {
                    UIApplication.getEVC().cancel()
                }
            })
            encryption.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "lockAction")?.resize(maxWidthHeight: 23) {
                encryption.setValue(image, forKey: "image")
            }
            actionSheet.addAction(encryption)

            if note.isEncrypted() {
                let removeEncryption = UIAlertAction(title: NSLocalizedString("Remove encryption", comment: ""), style: .default, handler: { _ in
                    self.removeEncryption(note: note)
                })

                removeEncryption.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
                if let image = UIImage(named: "actionDropEncryption") {
                    removeEncryption.setValue(image, forKey: "image")
                }

                actionSheet.addAction(removeEncryption)
            }

            let copy = UIAlertAction(title: NSLocalizedString("Copy plain text", comment: ""), style: .default, handler: { _ in
                self.copyAction(note: note, presentController: presentController)
            })
            copy.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")
            if let image = UIImage(named: "copyAction")?.resize(maxWidthHeight: 23) {
                copy.setValue(image, forKey: "image")
            }
            actionSheet.addAction(copy)

            let share = UIAlertAction(title: NSLocalizedString("Share", comment: ""), style: .default, handler: { _ in
                self.shareAction(note: note, presentController: presentController)
            })
            share.setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

            if let image = UIImage(named: "shareAction")?.resize(maxWidthHeight: 25) {
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

        var toInsert = [Note]()

        for note in notes {
            guard
                vc.isFitInCurrentSearchQuery(note: note),
                !self.notes.contains(where: {$0 === note})
            else { continue }

            toInsert.append(note)
        }

        guard toInsert.count > 0 else { return }
        vc.updateSpotlightIndex(notes: toInsert)

        let nonSorted = self.notes + toInsert
        let sorted = vc.storage.sortNotes(
            noteList: nonSorted,
            project: vc.searchQuery.project
        )

        var indexPaths = [IndexPath]()
        for note in toInsert {
            guard let index = sorted.firstIndex(of: note) else { continue }
            indexPaths.append(IndexPath(row: index, section: 0))
        }

        vc.storage.loadPins(notes: notes)
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

    private func renameAction(note: Note, presentController: UIViewController) {
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

            self.rename(note: note, to: name, presentController: presentController)
        }

        let title = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: title, style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        presentController.present(alertController, animated: true) {
            alertController.textFields![0].selectAll(nil)
        }
    }

    public func rename(note: Note, to name: String, presentController: UIViewController) {

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

        if presentController.isKind(of: EditorViewController.self), let evc = presentController as? EditorViewController {
            evc.setTitle(text: note.getShortTitle())
        }
    }

    private func removeAction(notes: [Note], presentController: UIViewController) {
        guard let vc = viewDelegate else { return }

        vc.sidebarTableView.removeTags(in: notes)
        for note in notes {
            note.remove()
        }
        removeRows(notes: notes)

        allowsMultipleSelectionDuringEditing = false
        setEditing(false, animated: true)
    }

    private func moveAction(notes: [Note], presentController: UIViewController) {
        let moveController = MoveViewController(notes: notes, notesTableView: self)
        let controller = UINavigationController(rootViewController:moveController)
        presentController.present(controller, animated: true, completion: nil)
    }

    private func dateAction(notes: [Note], presentController: UIViewController) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let datePickerViewController = storyBoard.instantiateViewController(withIdentifier: "datePickerViewController") as! DatePickerViewController
        datePickerViewController.notes = notes

        let nvc = UIApplication.getNC()
        nvc?.present(datePickerViewController, animated: true )
    }

    private func historyAction(note: Note, presentController: UIViewController) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let datePickerViewController = storyBoard.instantiateViewController(withIdentifier: "revisionsViewController") as! RevisionsViewController
        datePickerViewController.note = note

        let nvc = UIApplication.getNC()
        nvc?.present(datePickerViewController, animated: true )
    }

    private func copyAction(note: Note, presentController: UIViewController) {
        let item = [kUTTypeUTF8PlainText as String : note.content.string as Any]

        UIPasteboard.general.items = [item]
    }

    public func shareAction(note: Note, presentController: UIViewController, isHTML: Bool = false) {
        AudioServicesPlaySystemSound(1519)

        var tempURL = note.url
        if note.isTextBundle() {
            tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(note.getName()).zip")
            SSZipArchive.createZipFile(atPath: tempURL.path, withContentsOfDirectory: note.url.path, keepParentDirectory: true)
        }

        let objectsToShare = [tempURL] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        activityVC.excludedActivityTypes = [ UIActivity.ActivityType.addToReadingList ]

        presentController.present(activityVC, animated: true, completion: nil)

        guard let popOver = activityVC.popoverPresentationController else { return }
        popOver.permittedArrowDirections = .up

        if presentController.isKind(of: EditorViewController.self) {
            popOver.sourceView = presentController.view
            popOver.sourceRect = CGRect(x: presentController.view.bounds.midX, y: 80, width: 0, height: 0)

        } else if
            let presentController = presentController as? ViewController,
            let notesTable = presentController.notesTable, let i = notesTable.notes.firstIndex(where: {$0 === note}),
            let rowView = notesTable.cellForRow(at: IndexPath(row: i, section: 0)) {

            popOver.sourceView = rowView
            popOver.sourceRect = CGRect(x: presentController.view.bounds.midX, y: rowView.frame.height, width: 10, height: 10)
        }
    }

    public func duplicateAction(notes: [Note], presentController: UIViewController) {
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
        guard notes.count > 0 else { return }

        vc.getMasterPassword() { password in
            var isFirst = true
            for note in notes {
                if note.container == .encryptedTextPack {
                    let success = note.unEncrypt(password: password)
                    note.password = nil

                    if success && isFirst {
                        vc.savePassword(password)

                        DispatchQueue.main.async {
                            UIApplication.getEVC().refill()
                        }
                    }
                }
                isFirst = false
            }

            DispatchQueue.main.async {
                self.reloadRows(notes: notes, resetKeys: true)
            }
        }
    }

    public func moveRowUp(note: Note) {
        guard let vc = viewDelegate,
            vc.isNoteInsertionAllowed(),
            vc.isFitInCurrentSearchQuery(note: note),
            let at = notes.firstIndex(where: {$0 === note})
        else { return }

        var to = 0

        if note.project.sortBy == .modificationDate {
            to = note.isPinned ? 0 : notes.filter({ $0.isPinned }).count
        } else {
            let sorted = vc.storage.sortNotes(
                noteList: notes,
                project: vc.searchQuery.project
            )

            to = sorted.firstIndex(of: note) ?? at
        }

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
            let sorted = vc.storage.sortNotes(
                noteList: self.notes,
                project: vc.searchQuery.project
            )

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
            let sorted = vc.storage.sortNotes(
                noteList: self.notes,
                project: vc.searchQuery.project
            )

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
}
