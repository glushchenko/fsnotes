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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "noteCell", for: indexPath) as! NoteCellView
        
        cell.configure(note: notes[indexPath.row])
        cell.selectionStyle = .gray
        
        let view = UIView()
        view.mixedBackgroundColor = MixedColor(normal: 0xe2e5e4, night: 0x686372)
        cell.selectedBackgroundView = view

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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

            evc.fill(note: note)
            pageController.switchToEditor()
        }

        self.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete", handler: { (action , indexPath) -> Void in
            
            let note = self.notes[indexPath.row]

            if !note.isTrash() {
                if let trashURLs = note.removeFile() {
                    note.url = trashURLs[0]
                    note.parseURL()
                }
            } else {
                _ = note.removeFile()

                if note.isPinned {
                    note.removePin()
                }
            }

            DispatchQueue.main.async {
                self.removeByNotes(notes: [note])
            }
        })
        deleteAction.backgroundColor = UIColor(red:0.93, green:0.31, blue:0.43, alpha:1.0)

        let note = self.notes[indexPath.row]
        let pin = UITableViewRowAction(style: .default, title: note.isPinned ? "UnPin" : "Pin", handler: { (action , indexPath) -> Void in
            
            if note.isPinned {
                note.removePin()
            } else {
                note.addPin()
            }
            
            DispatchQueue.main.async {
                self.viewDelegate?.updateTable() {}
            }
        })
        pin.backgroundColor = UIColor(red:0.24, green:0.59, blue:0.94, alpha:1.0)

        let more = UITableViewRowAction(style: .default, title: "...", handler: { (action , indexPath) -> Void in

            let actionSheet = UIAlertController(title: note.title, message: nil, preferredStyle: .actionSheet)

            let rename = UIAlertAction(title: "Rename", style: .default, handler: { _ in
                self.renameAction(note: note)
            })
            actionSheet.addAction(rename)

            let move = UIAlertAction(title: "Move", style: .default, handler: { _ in
                self.moveAction(note: note)
            })
            actionSheet.addAction(move)

            let tags = UIAlertAction(title: "Tags", style: .default, handler: { _ in
                self.tagsAction(note: note)
            })
            actionSheet.addAction(tags)

            let copy = UIAlertAction(title: "Copy plain text", style: .default, handler: { _ in
                self.copyAction(note: note)
            })
            actionSheet.addAction(copy)

            let dismiss = UIAlertAction(title: "Cancel", style: .destructive, handler: nil)
            actionSheet.addAction(dismiss)

            self.viewDelegate?.present(actionSheet, animated: true, completion: nil)
        })
        more.backgroundColor = UIColor(red:0.13, green:0.69, blue:0.58, alpha:1.0)


        return [more, pin, deleteAction]
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
    }
    
    func removeByNotes(notes: [Note]) {
        for note in notes {
            if let i = self.notes.index(of: note) {
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
    
    public func updateLabel(note: Note) {
        if let i = self.notes.index(of: note) {
            let indexPath = IndexPath(row: i, section: 0)

            reloadRows(at: [indexPath], with: .automatic)
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

            guard let project = note.project, !project.fileExist(fileName: name, ext: note.url.pathExtension) else {
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

            DispatchQueue.main.async {
                if let i = self.notes.index(of: note) {
                    self.beginUpdates()
                    self.reloadRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
                    self.endUpdates()
                }
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        self.viewDelegate?.present(alertController, animated: true, completion: nil)
    }

    private func moveAction(note: Note) {
        let moveController = MoveViewController(note: note, notesTableView: self)
        let controller = UINavigationController(rootViewController:moveController)
        self.viewDelegate?.present(controller, animated: true, completion: nil)
    }

    private func tagsAction(note: Note) {
        let tagsController = TagsViewController(note: note, notesTableView: self)
        let controller = UINavigationController(rootViewController: tagsController)
        self.viewDelegate?.present(controller, animated: true, completion: nil)
    }

    private func copyAction(note: Note) {
        let item = [kUTTypeUTF8PlainText as String : note.content.string as Any]

        UIPasteboard.general.items = [item]
    }
}
