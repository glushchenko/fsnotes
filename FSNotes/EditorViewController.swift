//
//  EditorViewController.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 26.06.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation
import AppKit
import LocalAuthentication

class EditorViewController: NSViewController, NSTextViewDelegate {
    
    public var alert: NSAlert?
    public var noteLoading: ProgressState = .none
    
    public var vcEditor: EditTextView?
    public var vcTitleLabel: TitleTextField?
    public var vcEmptyEditAreaImage: NSImageView?
    
    public var vcPreviewButton: NSButton?
    public var vcShareButton: NSButton?
    public var vcLockUnlockButton: NSButton?
    public var vcEditorScrollView: EditorScrollView?
    
    public var currentPreviewState: PreviewState = UserDefaultsManagement.preview ? .on : .off
    
    public var previewResizeTimer = Timer()
    public var rowUpdaterTimer = Timer()
    public var editorUndoManager = UndoManager()
    
    public var breakUndoTimer = Timer()
    
    public func initView() {
        vcEditor?.delegate = self
    }
    
    @IBAction func toggleNotesLock(_ sender: Any) {
        var notes = [Note]()
        
        if let _ = sender as? NSButton, let note = vcEditor?.note {
            notes = [note]
        } else if let selected = ViewController.shared()?.notesTableView?.getSelectedNotes() {
            notes = selected
        }

        notes = lockUnlocked(notes: notes)
        guard notes.count > 0 else { return }

        getMasterPassword() { password, isTypedByUser in
            guard password.count > 0 else { return }

            for note in notes {
                var success = false

                if note.container == .encryptedTextPack {
                    success = note.unLock(password: password)
                    if success {
                        if notes.count == 0x01 {
                            note.password = password
                            DispatchQueue.main.async {
                                self.reloadAllOpenedWindows(note: note)
                            }
                        }

                        let insertTags = note.scanContentTags().0
                        DispatchQueue.main.async {
                            ViewController.shared()?.sidebarOutlineView?.addTags(insertTags)
                        }
                    }
                } else {
                    success = note.encrypt(password: password)
                    if success {
                        note.password = nil

                        DispatchQueue.main.async {
                            self.reloadAllOpenedWindows(note: note)
                            
                            ViewController.shared()?.focusTable()
                        }
                    }
                }

                if success && isTypedByUser {
                    self.save(password: password)
                }

                ViewController.shared()?.notesTableView.reloadRow(note: note)
            }
        }
    }
    
    @IBAction func togglePreview(_ sender: Any) {
        let firstResp = view.window?.firstResponder

        if (currentPreviewState == .on) {
            disablePreview()
        } else {
            //Preview mode doesn't support text search
            
            cancelTextSearch()
            currentPreviewState = .on
            refillEditArea()
            
            if let mdView = vcEditor?.editorViewController?.vcEditor?.markdownView {
                view.window?.makeFirstResponder(mdView)
            }
        }

        if let responder = firstResp, (
            ViewController.shared()?.search.currentEditor() == firstResp
            || responder.isKind(of: NotesTableView.self)
            || responder.isKind(of: SidebarOutlineView.self)
        ) {
            view.window?.makeFirstResponder(firstResp)
        } else {
            let responder = currentPreviewState == .on
                ? vcEditor?.markdownView
                : vcEditor
            
            view.window?.makeFirstResponder(responder)
        }

        UserDefaultsManagement.preview = currentPreviewState == .on
        vcEditor?.userActivity?.needsSave = true
    }
    
    @IBAction func shareSheet(_ sender: NSButton) {
        if let note = vcEditor?.note {
            let sharingPicker = NSSharingServicePicker(items: [
                note.content,
                note.url
            ])
            sharingPicker.delegate = self
            sharingPicker.show(relativeTo: NSZeroRect, of: sender, preferredEdge: .minY)
        }
    }
    
    func cancelTextSearch() {
        let menu = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.tag = NSTextFinder.Action.hideFindInterface.rawValue
        vcEditor?.performTextFinderAction(menu)
    }

    func disablePreview() {
        currentPreviewState = .off

        vcEditor?.markdownView?.removeFromSuperview()
        vcEditor?.markdownView = nil
        
        guard let editor = self.vcEditor else { return }
        editor.subviews.removeAll(where: { $0.isKind(of: MPreviewView.self) })

        refillEditArea()
    }
    
    public func viewDidResize() {
        guard currentPreviewState == .on else { return }

        if noteLoading != .incomplete {
            previewResizeTimer.invalidate()
            previewResizeTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(reloadPreview), userInfo: nil, repeats: false)
        }
    }
    
    @objc private func reloadPreview() {
        DispatchQueue.main.async {
            MPreviewView.template = nil
            self.refillEditArea(force: true)
        }
    }
    
    public func updateTitle(note: Note) {
        guard let vcTitleLabel = vcTitleLabel else { return }
        
        var titleString = note.getFileName()

        if titleString.isValidUUID {
            titleString = String()
        }

        if titleString.count > 0 {
            vcTitleLabel.stringValue = note.project.getNestedLabel() + " › " + titleString
        } else {
            vcTitleLabel.stringValue = note.project.getNestedLabel()
        }

        vcTitleLabel.currentEditor()?.selectedRange = NSRange(location: 0, length: 0)

        view.window?.title = vcTitleLabel.stringValue
    }
    
    func refillEditArea(saveTyping: Bool = false, force: Bool = false) {
        noteLoading = .incomplete
        vcPreviewButton?.state = currentPreviewState == .on ? .on : .off

        if let note = vcEditor?.note {
            vcEditor?.fill(note: note, saveTyping: saveTyping, force: force)
        }

        noteLoading = .done
    }
    
    public func unLock(notes: [Note]) {
        getMasterPassword() { password, isTypedByUser in
            guard password.count > 0 else { return }

            var i = 0
            for note in notes {
                let success = note.unLock(password: password)
                if success {

                    let insertTags = note.scanContentTags().0
                    DispatchQueue.main.async {
                        ViewController.shared()?.sidebarOutlineView?.addTags(insertTags)
                    }

                    if i == 0 {
                        note.password = password

                        DispatchQueue.main.async {
                            self.reloadAllOpenedWindows(note: note)
                        }

                        if isTypedByUser {
                            self.save(password: password)
                        }
                    }
                }

                ViewController.shared()?.notesTableView.reloadRow(note: note)
                i = i + 1
            }
        }
    }
    
    public func reloadAllOpenedWindows(note: Note) {
        let editors = AppDelegate.getEditTextViews()
        
        for editor in editors {
            if editor.note == note {
                editor.editorViewController?.refillEditArea(force: true)
            }
        }
    }

    public func getMasterPassword(completion: @escaping (String, Bool) -> ()) {
        if #available(OSX 10.12.2, *), UserDefaultsManagement.allowTouchID {
            let context = LAContext()
            context.localizedFallbackTitle = NSLocalizedString("Enter Master Password", comment: "")

            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
                masterPasswordPrompt(completion: completion)
                return
            }
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "To access secure data") { (success, evaluateError) in
                
                if !success {
                    self.masterPasswordPrompt(completion: completion)

                    return
                }

                do {
                    let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")
                    let password = try item.readPassword()

                    completion(password, false)
                    return
                } catch {
                    print(error)
                }

                self.masterPasswordPrompt(completion: completion)
            }
        } else {
            masterPasswordPrompt(completion: completion)
        }
    }
    
    private func masterPasswordPrompt(completion: @escaping (String, Bool) -> ()) {
        DispatchQueue.main.async {
            guard let window = self.view.window else { return }

            self.alert = NSAlert()
            guard let alert = self.alert else { return }

            let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
            alert.messageText = NSLocalizedString("Master password:", comment: "")
            alert.informativeText = NSLocalizedString("Please enter password for current note", comment: "")
            alert.accessoryView = field
            alert.alertStyle = .informational
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    completion(field.stringValue, true)
                }

                self.alert = nil
            }

            field.becomeFirstResponder()
        }
    }

    private func save(password: String) {
        guard password.count > 0, UserDefaultsManagement.savePasswordInKeychain else { return }

        let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")

        var oldPassword = String()
        do {
            oldPassword = try item.readPassword()
        } catch {/*_*/}

        do {
            guard oldPassword.count == 0 else { return }

            try item.savePassword(password)
        } catch {
            print("Master password saving error: \(error)")
        }
    }

    public func lockUnlocked(notes: [Note]) -> [Note] {
        var notes = notes
        var isFirst = true

        for note in notes {
            if note.isUnlocked() && note.isEncrypted() {
                if note.lock() && isFirst {
                    self.reloadAllOpenedWindows(note: note)
                }

                removeTags(note: note)
                notes.removeAll { $0 === note }
            }

            isFirst = false
            ViewController.shared()?.notesTableView.reloadRow(note: note)
        }
        
        // Focus notes list if active main window
        if let vc = view.window?.contentViewController as? ViewController, let mainWindow = view.window {
            mainWindow.makeFirstResponder(vc.notesTableView)
        }

        return notes
    }

    public func decryptUnlocked(notes: [Note]) -> [Note] {
        var notes = notes

        for note in notes {
            if note.isUnlocked() {
                if note.unEncryptUnlocked() {
                    notes.removeAll { $0 === note }
                    ViewController.shared()?.notesTableView.reloadRow(note: note)
                }
            }
        }

        return notes
    }
    
    public func removeTags(note: Note) {
        let tags = note.tags
        note.tags = []
        ViewController.shared()?.sidebarOutlineView?.removeTags(tags)
    }
    
    public func dropTitle() {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "FSNotes"

        vcTitleLabel?.stringValue = appName
        view.window?.title = appName
    }
    
    func focusEditArea() {
        guard let editor = vcEditor, let note = editor.note,
            currentPreviewState == .off || note.isRTF(),
            note.container != .encryptedTextPack
        else { return }

        editor.window?.makeFirstResponder(editor)

        if let ntv = ViewController.shared()?.notesTableView, ntv.selectedRow > -1 {
            vcEditor?.isEditable = true
            vcEmptyEditAreaImage?.isHidden = true
        }
    }
        
    // Changed main edit view
    func textDidChange(_ notification: Notification) {
        guard let editor = vcEditor,
              let note = editor.note,
              let vc = ViewController.shared() else { return }

        Git.sharedInstance().cleanCheckoutHistory()

        vc.blockFSUpdates()

        if (
            currentPreviewState == .off
            && editor.isEditable
        ) {
            editor.removeHighlight()
            editor.saveImages()

            note.save(attributed: editor.attributedString())
            vc.reSort(note: note)
        }

        breakUndoTimer.invalidate()
        breakUndoTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(breakUndo), userInfo: nil, repeats: true)
    }
            
    @objc func breakUndo() {
        guard let editor = vcEditor else { return }
        
        if (
           currentPreviewState == .off
           && editor.isEditable
        ) {
            editor.breakUndoCoalescing()
        }
    }
}
