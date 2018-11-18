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

class NotesTableView: UITableView,
    UITableViewDelegate,
    UITableViewDataSource {
    
    var notes = [Note]()
    var storage = Storage.sharedInstance()
    var viewDelegate: ViewController? = nil
    var cellHeights = [IndexPath:CGFloat]()
    public var selectedIndexPaths: [IndexPath]?

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if notes.indices.contains(indexPath.row) {
            let note = notes[indexPath.row]
            if let urls = note.getImagePreviewUrl(), urls.count > 0 {
                return 160
            }
        }

        return 75
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeights[indexPath] ?? 75
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "noteCell", for: indexPath) as! NoteCellView

        guard self.notes.indices.contains(indexPath.row) else { return cell }
        
        let note = self.notes[indexPath.row]
        note.load(note.url)

        cell.configure(note: self.notes[indexPath.row])
        cell.selectionStyle = .gray

        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        cell.loadImagesPreview()
        cell.attachTitleAndPreview(note: note)

        return cell
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.selectedIndexPaths = self.indexPathsForSelectedRows
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            self.selectedIndexPaths = self.indexPathsForSelectedRows
        }

        guard !self.isEditing else { return }

        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let viewController = pageController.orderedViewControllers[1] as? UINavigationController else {

                self.deselectRow(at: indexPath, animated: true)
            return
        }

        let note = notes[indexPath.row]
        if let evc = viewController.viewControllers[0] as? EditorViewController {
            if let editArea = evc.editArea, let u = editArea.undoManager {
                u.removeAllActions()
            }

            self.deselectRow(at: indexPath, animated: true)
            evc.fill(note: note)
            pageController.switchToEditor()
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete", handler: { (action , indexPath) -> Void in
            
            let note = self.notes[indexPath.row]
            note.remove()

            DispatchQueue.main.async {
                self.removeByNotes(notes: [note])
            }
        })
        deleteAction.backgroundColor = UIColor(red:0.93, green:0.31, blue:0.43, alpha:1.0)

        let note = self.notes[indexPath.row]
        let pin = UITableViewRowAction(style: .default, title: note.isPinned ? "UnPin" : "Pin", handler: { (action , indexPath) -> Void in
            
            guard let cell = self.cellForRow(at: indexPath) as? NoteCellView else { return }

            note.togglePin()
            cell.configure(note: note)

            let filter = self.viewDelegate?.search.text ?? ""
            let resorted = self.storage.sortNotes(noteList: self.notes, filter: filter)
            guard let newIndex = resorted.firstIndex(of: note) else { return }

            let newIndexPath = IndexPath(row: newIndex, section: 0)
            self.moveRow(at: indexPath, to: newIndexPath)
            self.notes = resorted

            self.reloadRows(at: [newIndexPath], with: .automatic)
            self.reloadRows(at: [indexPath], with: .automatic)
        })
        pin.backgroundColor = UIColor(red:0.24, green:0.59, blue:0.94, alpha:1.0)

        let more = UITableViewRowAction(style: .default, title: "...", handler: { (action , indexPath) -> Void in
            self.actionsSheet(notes: [note], showAll: true)
        })
        more.backgroundColor = UIColor(red:0.13, green:0.69, blue:0.58, alpha:1.0)


        return [more, pin, deleteAction]
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)

        let frame = tableView.rectForRow(at: indexPath)
        self.cellHeights[indexPath] = frame.size.height
    }

    public func actionsSheet(notes: [Note], showAll: Bool = false) {
        let note = notes.first!
        let actionSheet = UIAlertController(title: note.title, message: nil, preferredStyle: .actionSheet)

        if showAll {
            let rename = UIAlertAction(title: "Rename", style: .default, handler: { _ in
                self.renameAction(note: note)
            })
            actionSheet.addAction(rename)
        } else {
            let remove = UIAlertAction(title: "Delete", style: .default, handler: { _ in
                self.removeAction(notes: notes)
            })
            actionSheet.addAction(remove)
        }

        let move = UIAlertAction(title: "Move", style: .default, handler: { _ in
            if self.isEditing {
                self.allowsMultipleSelectionDuringEditing = false
                self.setEditing(false, animated: true)
            }

            self.moveAction(notes: notes)
        })
        actionSheet.addAction(move)

        let tags = UIAlertAction(title: "Tags", style: .default, handler: { _ in
            if self.isEditing {
                self.allowsMultipleSelectionDuringEditing = false
                self.setEditing(false, animated: true)
            }
            
            self.tagsAction(notes: notes)
        })
        actionSheet.addAction(tags)

        if showAll {
            let copy = UIAlertAction(title: "Copy plain text", style: .default, handler: { _ in
                self.copyAction(note: note)
            })
            actionSheet.addAction(copy)
        }

        let dismiss = UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in

            if self.isEditing {
                self.setEditing(false, animated: true)
            }
        })
        actionSheet.addAction(dismiss)

        if let view = self.superview {
            actionSheet.popoverPresentationController?.sourceView = view
            actionSheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.size.width / 2.0, y: view.bounds.size.height, width: 2.0, height: 1.0)
        }

        self.viewDelegate?.present(actionSheet, animated: true, completion: nil)
    }
    
    func removeByNotes(notes: [Note]) {
        for note in notes {
            if let i = self.notes.index(where: {$0 === note}) {
                let indexPath = IndexPath(row: i, section: 0)
                self.notes.remove(at: i)
                deleteRows(at: [indexPath], with: .fade)
            }
        }
    }
    
    @objc func handleLongPress(longPressGesture:UILongPressGestureRecognizer) {
        let p = longPressGesture.location(in: self)
        let indexPath = self.indexPathForRow(at: p)
        if indexPath == nil {
            print("Long press on table view, not row.")
        } else if (longPressGesture.state == UIGestureRecognizerState.began) {
            let alert = UIAlertController.init(title: "Are you sure you want to remove note?", message: "This action cannot be undone.", preferredStyle: .alert)
            
            let remove = UIAlertAction(title: "Remove", style: .destructive) { (alert: UIAlertAction!) -> Void in
                guard let row = indexPath?.row else {
                    return
                }
                
                let note = self.notes[row]
                self.storage.removeNotes(notes: [note]) {_ in 
                    DispatchQueue.main.async {
                        self.removeByNotes(notes: [note])
                    }
                }
            }
            let cancel = UIAlertAction(title: "Cancel", style: .default)
            
            alert.addAction(cancel)
            alert.addAction(remove)
            
            self.viewDelegate?.present(alert, animated: true, completion:nil)
        }
    }
    
    public func updateRowView(note: Note) {
        if let i = self.notes.index(where: {$0 === note}) {
            let indexPath = IndexPath(row: i, section: 0)

            DispatchQueue.main.async {
                if let cell = self.cellForRow(at: indexPath) as? NoteCellView {
                    cell.updateView()
                }
            }
        }
    }

    private func renameAction(note: Note) {
        let alertController = UIAlertController(title: "Rename note:", message: nil, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.placeholder = "Enter note name"
            textField.attributedText = NSAttributedString(string: note.title)
        }

        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            guard let name = alertController.textFields?[0].text, name.count > 0 else {
                return
            }

            guard !note.project.fileExist(fileName: name, ext: note.url.pathExtension) else {
                let alert = UIAlertController(title: "Oops 👮‍♂️", message: "Note with this name already exist", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                self.viewDelegate?.present(alert, animated: true, completion: nil)
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

            self.updateRowView(note: note)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.viewDelegate?.present(alertController, animated: true, completion: nil)
    }

    private func removeAction(notes: [Note]) {
        for note in notes {
            note.remove()
        }

        self.removeByNotes(notes: notes)

        self.allowsMultipleSelectionDuringEditing = false
        self.setEditing(false, animated: true)
    }

    private func moveAction(notes: [Note]) {
        let moveController = MoveViewController(notes: notes, notesTableView: self)
        let controller = UINavigationController(rootViewController:moveController)
        self.viewDelegate?.present(controller, animated: true, completion: nil)
    }

    private func tagsAction(notes: [Note]) {
        let tagsController = TagsViewController(notes: notes, notesTableView: self)
        let controller = UINavigationController(rootViewController: tagsController)
        self.viewDelegate?.present(controller, animated: true, completion: nil)
    }

    private func copyAction(note: Note) {
        let item = [kUTTypeUTF8PlainText as String : note.content.string as Any]

        UIPasteboard.general.items = [item]
    }

    public func moveRowUp(note: Note) {
        if let i = self.notes.index(where: {$0 === note}) {
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
            let sidebarItem = self.viewDelegate?.sidebarTableView.getSidebarItem()

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
}
