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
import WebKit

class EditorViewController: NSViewController, NSTextViewDelegate, WebFrameLoadDelegate {
    
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
    public var printWebView = WebView()
    
    // git
    public var isGitProcessLocked = false
    public var snapshotsTimer = Timer()
    public var lastSnapshot: Int = 0
    
    public func initView() {
        vcEditor?.delegate = self
    }
    
    public func getSelectedNotes() -> [Note]? {
        
        // Active main window
        if let cvc = NSApplication.shared.keyWindow?.contentViewController,
            cvc.isKind(of: ViewController.self),
            let vc = ViewController.shared(),
            let selected = vc.notesTableView.getSelectedNotes() {
            return selected
        }
        
        // Active note window
        if let note = vcEditor?.note {
            return [note]
        }
        
        return nil
    }
    
    // MARK: Window bar actions
    
    @IBAction func toggleNotesLock(_ sender: Any) {
        guard var notes = getSelectedNotes() else { return }
        
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

                DispatchQueue.main.async {
                    ViewController.shared()?.notesTableView.reloadRow(note: note)
                }
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
    
    // MARK: File menu
    
    @IBAction func printNotes(_ sender: NSMenuItem) {
        guard let notes = getSelectedNotes(), let note = notes.first else { return }
        
        if note.isMarkdown() {
            printMarkdownPreview()
            return
        }
        
        let pv = NSTextView(frame: NSMakeRect(0, 0, 528, 688))
        pv.textStorage?.append(note.content)
        
        let printInfo = NSPrintInfo.shared
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.scalingFactor = 1
        printInfo.topMargin = 40
        printInfo.leftMargin = 40
        printInfo.rightMargin = 40
        printInfo.bottomMargin = 40
        
        let operation: NSPrintOperation = NSPrintOperation(view: pv, printInfo: printInfo)
        operation.printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
        operation.printPanel.options.insert(NSPrintPanel.Options.showsOrientation)
        operation.run()
    }
    
    @IBAction func finderMenu(_ sender: NSMenuItem) {
        guard let notes = getSelectedNotes() else { return }
        
        var urls = [URL]()
        for note in notes {
            urls.append(note.url)
        }
        
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
    
    @IBAction func pinMenu(_ sender: Any) {
        guard let notes = getSelectedNotes() else { return }
        
        ViewController.shared()?.pin(selectedNotes: notes)
    }
    
    @IBAction func editorMenu(_ sender: Any) {
        guard let notes = getSelectedNotes() else { return }
        
        ViewController.shared()?.external(selectedNotes: notes)
    }
    
    @IBAction func copyURL(_ sender: Any) {
        guard let note = getSelectedNotes()?.first else { return }
        
        if let title = note.title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {

            let name = "fsnotes://find?id=\(title)"
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(name, forType: NSPasteboard.PasteboardType.string)
            
            let notification = NSUserNotification()
            notification.title = "FSNotes"
            notification.informativeText = NSLocalizedString("URL has been copied to clipboard", comment: "")
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    @IBAction func copyTitle(_ sender: Any) {
        guard let note = getSelectedNotes()?.first else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(note.title, forType: NSPasteboard.PasteboardType.string)
    }
    
    @IBAction func removeNoteEncryption(_ sender: Any) {
        guard var notes = getSelectedNotes() else { return }

        notes = decryptUnlocked(notes: notes)
        guard notes.count > 0 else { return }

        UserDataService.instance.fsUpdatesDisabled = true
        getMasterPassword() { password, isTypedByUser in
            for note in notes {
                if note.container == .encryptedTextPack {
                    let success = note.unEncrypt(password: password)
                    if success && notes.count == 0x01 {
                        note.password = nil
                        DispatchQueue.main.async {
                            self.reloadAllOpenedWindows(note: note)
                        }
                    }
                }
                
                ViewController.shared()?.notesTableView.reloadRow(note: note)
            }
            UserDataService.instance.fsUpdatesDisabled = false
        }
    }
    
    @IBAction func changeCreationDate(_ sender: Any) {
        guard let notes = getSelectedNotes() else { return }
        guard let note = notes.first else { return }
        guard let creationDate = note.getFileCreationDate() else { return }
        guard let window = view.window else { return }

        alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.string(from: creationDate)

        field.stringValue = date
        field.placeholderString = "2020-08-28 21:59:07"

        alert?.messageText = NSLocalizedString("Change Creation Date", comment: "Menu") + ":"
        alert?.accessoryView = field
        alert?.alertStyle = .informational
        alert?.addButton(withTitle: "OK")
        alert?.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                for note in notes {
                    if note.setCreationDate(string: field.stringValue) {
                        ViewController.shared()?.notesTableView.reloadRow(note: note)
                    }
                }
            }

            self.alert = nil
        }

        field.becomeFirstResponder()
    }
    
    // MARK: Dep methods
    
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
                        ViewController.shared()?.notesTableView.reloadRow(note: note)
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
                    reloadAllOpenedWindows(note: note)
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
