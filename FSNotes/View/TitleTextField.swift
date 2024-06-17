//
//  TitleTextField.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 5/10/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Carbon.HIToolbox

class TitleTextField: NSTextField {
    public var restoreResponder: NSResponder?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command)
            && event.characters?.unicodeScalars.first == "c"
            && !event.modifierFlags.contains(.shift)
            && !event.modifierFlags.contains(.control)
            && !event.modifierFlags.contains(.option) {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(self.stringValue, forType: NSPasteboard.PasteboardType.string)
        }

        return super.performKeyEquivalent(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        if let vc = ViewController.shared(),
            let note = vc.editor.note {
            stringValue = note.getFileName()
        }

        return super.becomeFirstResponder()
    }

    override func textDidEndEditing(_ notification: Notification) {
        guard stringValue.count > 0,
            let vc = ViewController.shared(),
            let note = vc.editor.note
        else { return }

        let currentTitle = stringValue
        let currentName = note.getFileName()

        defer {
            updateNotesTableView()
            editModeOff()
        }
        
        if currentName != currentTitle {
            rename(currentTitle: currentTitle, note: note)
            return
        }

        vc.updateTitle(note: note)
        self.resignFirstResponder()
        updateNotesTableView()
        vc.titleLabel.isEditable = false
        vc.titleLabel.isEnabled = false
    }

    public func rename(currentTitle: String, note: Note) {
        guard let vc = ViewController.shared() else { return }

        _ = vc.lockUnlocked(notes: [note])

        let currentName = note.getFileName()
        let ext = note.url.pathExtension
        let fileName =
            currentTitle
                .trimmingCharacters(in: CharacterSet.whitespaces)
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "/", with: "")

        let dst = note.project.url
            .appendingPathComponent(fileName)
            .appendingPathExtension(ext)

        let hasCaseSensitiveDiffOnly = currentName.lowercased() == fileName.lowercased()

        if !FileManager.default.fileExists(atPath: dst.path) || hasCaseSensitiveDiffOnly {
            _ = note.move(to: dst, forceRewrite: hasCaseSensitiveDiffOnly)

            vc.updateTitle(note: note)
            updateNotesTableView()

            vc.reSort(note: note)
        } else {
            vc.updateTitle(note: note)
            self.resignFirstResponder()
            updateNotesTableView()
            vc.titleLabel.isEditable = false
            vc.titleLabel.isEnabled = false

            let alert = NSAlert()
            let informativeText = NSLocalizedString("Note with name \"%@\" already exists in selected directory.", comment: "")

            alert.alertStyle = .critical
            alert.informativeText = String(format: informativeText, currentTitle)
            alert.runModal()
        }
    }

    public func editModeOn() {
        self.isEnabled = true
        self.isEditable = true
        
        MainWindowController.shared()?.makeFirstResponder(self)
    }
    
    public func editModeOff() {
        self.isEnabled = false
        self.isEditable = false

        guard let vc = ViewController.shared(),
              let note = vc.editor.note else { return }

        vc.updateTitle(note: note)
    }
    
    public func updateNotesTableView() {
        guard let vc = ViewController.shared(), let note = vc.editor.note else { return }

        if (note.container == .encryptedTextPack && !note.isUnlocked()) || !note.project.settings.isFirstLineAsTitle() {
            vc.notesTableView.reloadRow(note: note)
        }

        if let responder = restoreResponder {
            window?.makeFirstResponder(responder)
        }
    }
}
