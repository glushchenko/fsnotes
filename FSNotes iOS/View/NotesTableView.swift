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

class NotesTableView: UITableView,
    UITableViewDelegate,
    UITableViewDataSource,
    UITableViewDragDelegate,
    SwipeTableViewCellDelegate {

    var notes = [Note]()
    var viewDelegate: ViewController? = nil
    var cellHeights = [IndexPath:CGFloat]()
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

            if !note.isLoaded && !note.isLoadedFromCache {
                note.load()
            }

            if let urls = note.imageUrl, urls.count > 0 {
                if note.preview.count == 0 {
                    if note.getTitle() != nil {

                        // Title + image
                        return 130
                    }

                    // Images only
                    return 110
                }

                // Title + Prevew + Images
                return 160
            }
        }

        return 75
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "noteCell", for: indexPath) as! NoteCellView

        cell.delegate = self

        guard self.notes.indices.contains(indexPath.row) else { return cell }

        let note = self.notes[indexPath.row]
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

        let index = UserDefaultsManagement.previewMode ? 2 : 1

        if note.container == .encryptedTextPack {
            viewDelegate?.unLock(notes: [note], completion: { notes in
                DispatchQueue.main.async {
                    guard note.container != .encryptedTextPack else {
                        self.invalidPasswordAlert()
                        return
                    }

                    self.reloadRow(note: note)
                    NotesTextProcessor.highlight(note: note)

                    self.fill(note: note, indexPath: indexPath, index: index)
                }
            })
            
            return
        }

        fill(note: note, indexPath: indexPath, index: index)
    }

    private func fill(note: Note, indexPath: IndexPath, index: Int) {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else {
            return
        }

        let evc = UIApplication.getEVC()

        evc.fill(note: note, clearPreview: true) {
            bvc.containerController.selectController(atIndex: index, animated: true)

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
        guard let storage = viewDelegate?.storage, !UserDefaultsManagement.sidebarIsOpened
        else { return nil }

        guard orientation == .right else { return nil }
        let note = self.notes[indexPath.row]

        let deleteTitle = NSLocalizedString("Delete", comment: "Table row action")
        let deleteAction = SwipeAction(style: .destructive, title: deleteTitle) { action, indexPath in
            note.remove()

            self.viewDelegate?.sidebarTableView.loadAllTags()
            self.removeRows(notes: [note])

            if note.isEmpty() {
                storage.removeBy(note: note)
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

            let filter = self.viewDelegate?.search.text ?? ""
            let resorted = storage.sortNotes(noteList: self.notes, filter: filter)
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

    /*
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {



        let deleteAction = UITableViewRowAction(style: .default, title: NSLocalizedString("Delete", comment: ""), handler: { (action , indexPath) -> Void in

        })
        deleteAction.backgroundColor = UIColor(red:0.93, green:0.31, blue:0.43, alpha:1.0)

        let note = self.notes[indexPath.row]
        let title = note.isPinned
            ? NSLocalizedString("UnPin", comment: "")
            : NSLocalizedString("Pin", comment: "")

        let pin = UITableViewRowAction(style: .default, title: title, handler: { (action , indexPath) -> Void in
            
            guard let cell = self.cellForRow(at: indexPath) as? NoteCellView else { return }

            note.togglePin()
            cell.configure(note: note)

            let filter = self.viewDelegate?.search.text ?? ""
            let resorted = storage.sortNotes(noteList: self.notes, filter: filter)
            guard let newIndex = resorted.firstIndex(of: note) else { return }

            let newIndexPath = IndexPath(row: newIndex, section: 0)
            self.moveRow(at: indexPath, to: newIndexPath)
            self.notes = resorted

            self.reloadRows(at: [newIndexPath], with: .automatic)
            self.reloadRows(at: [indexPath], with: .automatic)
        })
        pin.backgroundColor = UIColor(red:0.24, green:0.59, blue:0.94, alpha:1.0)

        let more = UITableViewRowAction(style: .default, title: "...", handler: { (action , indexPath) -> Void in
            self.actionsSheet(notes: [note], showAll: true, presentController: self.viewDelegate!)
        })
        more.backgroundColor = UIColor(red:0.13, green:0.69, blue:0.58, alpha:1.0)


        return [more, pin, deleteAction]
    }
 */

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

        let frame = tableView.rectForRow(at: indexPath)
        self.cellHeights[indexPath] = frame.size.height
    }

    public func actionsSheet(notes: [Note], showAll: Bool = false, presentController: UIViewController) {
        let note = notes.first!
        let actionSheet = UIAlertController(title: note.getShortTitle(), message: nil, preferredStyle: .actionSheet)

        if showAll {
            let rename = UIAlertAction(title: NSLocalizedString("Rename", comment: ""), style: .default, handler: { _ in
                self.renameAction(note: note, presentController: presentController)
            })
            actionSheet.addAction(rename)
        } else {
            let remove = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .default, handler: { _ in
                self.removeAction(notes: notes, presentController: presentController)
            })
            actionSheet.addAction(remove)
        }

        let move = UIAlertAction(title: NSLocalizedString("Move", comment: ""), style: .default, handler: { _ in
            if self.isEditing {
                self.allowsMultipleSelectionDuringEditing = false
                self.setEditing(false, animated: true)
            }

            self.moveAction(notes: notes, presentController: presentController)
        })
        actionSheet.addAction(move)

        if !UserDefaultsManagement.inlineTags {
            let tags = UIAlertAction(title: NSLocalizedString("Tags", comment: ""), style: .default, handler: { _ in
                if self.isEditing {
                    self.allowsMultipleSelectionDuringEditing = false
                    self.setEditing(false, animated: true)
                }
                
                self.tagsAction(notes: notes, presentController: presentController)
            })
            actionSheet.addAction(tags)
        }

        if showAll {
            let encryption = UIAlertAction(title: NSLocalizedString("Lock/unlock", comment: ""), style: .default, handler: { _ in
                self.viewDelegate?.toggleNotesLock(notes: [note])
            })
            actionSheet.addAction(encryption)

//            if note.container == .encryptedTextPack {
//                let share = UIAlertAction(title: NSLocalizedString("Remove encryption", comment: ""), style: .default, handler: { _ in
//                    self.removeEncryption(note: note)
//                })
//                actionSheet.addAction(share)
//            }

            let copy = UIAlertAction(title: NSLocalizedString("Copy plain text", comment: ""), style: .default, handler: { _ in
                self.copyAction(note: note, presentController: presentController)
            })
            actionSheet.addAction(copy)

            let share = UIAlertAction(title: NSLocalizedString("Share", comment: ""), style: .default, handler: { _ in
                self.shareAction(note: note, presentController: presentController)
            })
            actionSheet.addAction(share)
        }

        let dismiss = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive, handler: { _ in

            if self.isEditing {
                self.setEditing(false, animated: true)
            }
        })
        actionSheet.addAction(dismiss)

        if let view = self.superview {
            actionSheet.popoverPresentationController?.sourceView = view
            actionSheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.size.width / 2.0, y: view.bounds.size.height, width: 2.0, height: 1.0)
        }

        presentController.present(actionSheet, animated: true, completion: nil)
    }
    
    public func removeRows(notes: [Note]) {
        for note in notes {
            if let i = self.notes.firstIndex(where: {$0 === note}) {
                let indexSet = IndexPath(row: i, section: 0)
                self.notes.remove(at: i)
                deleteRows(at: [indexSet], with: .automatic)
            }
        }
        
        self.viewDelegate?.updateNotesCounter()
    }

    public func insertRows(notes: [Note]) {
        let sidebarItem = viewDelegate?.sidebarTableView.getSidebarItem()
        let i = self.getInsertPosition()

        for note in notes {
            guard let mainController = self.viewDelegate, mainController.isFit(note: note, sidebarItem: sidebarItem) else { return }

            if !self.notes.contains(where: {$0 === note}) {
                self.notes.insert(note, at: i)
                self.insertRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
            }
        }
    }

    public func reloadRows(notes: [Note]) {
        for note in notes {
            reloadRow(note: note)
        }
    }
    
    @objc func handleLongPress(longPressGesture: UILongPressGestureRecognizer) {
        guard let storage = viewDelegate?.storage else { return }

        let p = longPressGesture.location(in: self)
        let indexPath = self.indexPathForRow(at: p)
        if indexPath == nil {
            print("Long press on table view, not row.")
        } else if (longPressGesture.state == UIGestureRecognizer.State.began) {
            let title = NSLocalizedString("Are you sure you want to remove note?", comment: "")
            let message = NSLocalizedString("This action cannot be undone.", comment: "")
            let alert = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
            
            let remove = UIAlertAction(title: NSLocalizedString("Remove", comment: ""), style: .destructive) { (alert: UIAlertAction!) -> Void in
                guard let row = indexPath?.row else {
                    return
                }
                
                let note = self.notes[row]
                storage.removeNotes(notes: [note]) {_ in
                    DispatchQueue.main.async {
                        self.removeRows(notes: [note])
                    }
                }
            }
            let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .default)
            
            alert.addAction(cancel)
            alert.addAction(remove)
            
            self.viewDelegate?.present(alert, animated: true, completion:nil)
        }
    }
    
    public func reloadRow(note: Note) {
        DispatchQueue.main.async {
            if let i = self.notes.firstIndex(where: {$0 === note}) {
                let indexPath = IndexPath(row: i, section: 0)

                if let cell = self.cellForRow(at: indexPath) as? NoteCellView {
                    cell.configure(note: note)
                    cell.updateView()
                }
            }
        }
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

            guard !note.project.fileExist(fileName: name, ext: note.url.pathExtension) else {
                let message = NSLocalizedString("Note with this name already exist", comment: "")
                let alert = UIAlertController(title: "Oops 👮‍♂️", message: message, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                presentController.present(alert, animated: true, completion: nil)
                return
            }

            let isPinned = note.isPinned
            let dst = note.getNewURL(name: name)

            note.removePin()
            if note.move(to: dst) {
                note.url = dst
                note.parseURL()
            }

            if isPinned {
                note.addPin()
            }

            self.reloadRow(note: note)

            if presentController.isKind(of: EditorViewController.self), let evc = presentController as? EditorViewController {
                evc.setTitle(text: note.getShortTitle())
            }
        }

        let title = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: title, style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        presentController.present(alertController, animated: true) {
            alertController.textFields![0].selectAll(nil)
        }
    }

    private func removeAction(notes: [Note], presentController: UIViewController) {
        for note in notes {
            note.remove()
        }

        self.removeRows(notes: notes)

        self.allowsMultipleSelectionDuringEditing = false
        self.setEditing(false, animated: true)

        self.viewDelegate?.sidebarTableView.loadAllTags()
    }

    private func moveAction(notes: [Note], presentController: UIViewController) {
        let moveController = MoveViewController(notes: notes, notesTableView: self)
        let controller = UINavigationController(rootViewController:moveController)
        presentController.present(controller, animated: true, completion: nil)
    }

    private func tagsAction(notes: [Note], presentController: UIViewController) {
        let tagsController = TagsViewController(notes: notes, notesTableView: self)
        let controller = UINavigationController(rootViewController: tagsController)
        presentController.present(controller, animated: true, completion: nil)
    }

    private func copyAction(note: Note, presentController: UIViewController) {
        let item = [kUTTypeUTF8PlainText as String : note.content.string as Any]

        UIPasteboard.general.items = [item]
    }

    public func shareAction(note: Note, presentController: UIViewController, isHTML: Bool = false) {
        AudioServicesPlaySystemSound(1519)

        var string = note.content.string
        if isHTML {
            string = renderMarkdownHTML(markdown:  note.content.unLoadImages().string)!
        }

        let objectsToShare = [string] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        activityVC.excludedActivityTypes = [UIActivity.ActivityType.airDrop, UIActivity.ActivityType.addToReadingList]

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

    private func decryptUnlocked(notes: [Note]) -> [Note] {
        var notes = notes

        for note in notes {
            if note.isUnlocked() {
                if note.unEncryptUnlocked() {
                    notes.removeAll { $0 === note }

                    note.invalidateCache()
                    reloadRow(note: note)
                }
            }
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
                    if success && isFirst {
                        DispatchQueue.main.async {
                            UIApplication.getEVC().refill()
                        }
                    }
                }
                self.reloadRow(note: note)
                isFirst = false
            }
        }
    }

    public func moveRowUp(note: Note) {
        if let i = self.notes.firstIndex(where: {$0 === note}) {
            let position = note.isPinned ? 0 : self.getInsertPosition()

            if i == position {
                return
            }

            let sidebarItem = self.viewDelegate?.sidebarTableView.getSidebarItem()

            guard let mainController = self.viewDelegate, mainController.isFit(note: note, sidebarItem: sidebarItem) else { return }

            self.notes.remove(at: i)
            self.notes.insert(note, at: position)

            moveRow(at: IndexPath(item: i, section: 0), to: IndexPath(item: position, section: 0))
        }
    }

    public func insertRow(note: Note) {
        let i = self.getInsertPosition()

        DispatchQueue.main.async {
            let sidebarItem = self.viewDelegate?.sidebarTableView.getSelectedSidebarItem()

            guard let mainController = self.viewDelegate, mainController.isFit(note: note, sidebarItem: sidebarItem) else { return }

            if !self.notes.contains(where: {$0 === note}) {
                self.notes.insert(note, at: i)
                self.insertRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
            }
        }
    }

    private func getInsertPosition() -> Int {
        var i = 0

        for note in self.notes {
            if note.isPinned {
                i += 1
            }
        }

        return i
    }

    @objc public func toggleSelectAll() {
        guard self.isEditing else {
            openPopover()
            return
        }

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

    private func openPopover() {
        let type = viewDelegate?.sidebarTableView.getSidebarItem()?.type

        guard type == nil || type == .Category || type == .All || type == .Inbox else { return }

        let vc = FolderPopoverViewControler()
        let height = Int(vc.tableView.rowHeight) * vc.actions.count

        vc.preferredContentSize = CGSize(width: 200, height: height)
        vc.modalPresentationStyle = .popover
        if let pres = vc.presentationController {
            pres.delegate = viewDelegate
        }

        viewDelegate?.present(vc, animated: true)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = (viewDelegate?.currentFolder!)

            var cgRect = (viewDelegate?.currentFolder!)!.bounds
            cgRect.origin.y = cgRect.origin.y + 20
            pop.sourceRect = cgRect
        }

        AudioServicesPlaySystemSound(1519)
    }

    private func invalidPasswordAlert() {
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController
        else { return }

        let invalid = NSLocalizedString("Invalid Password", comment: "")
        let message = NSLocalizedString("Please enter valid password", comment: "")
        let alert = UIAlertController(title: invalid, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

        bvc.present(alert, animated: true, completion: nil)
    }

    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {

        guard let cell = tableView.cellForRow(at: indexPath) as? NoteCellView,
            let string = cell.note?.url.path
        else { return [] }

        guard let data = string.data(using: .utf8) else { return [] }
        let itemProvider = NSItemProvider(item: data as NSData, typeIdentifier: kUTTypePlainText as String)

        return [UIDragItem(itemProvider: itemProvider)]
    }
}
