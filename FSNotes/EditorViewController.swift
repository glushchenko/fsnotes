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

class EditorViewController: NSViewController, NSTextViewDelegate, WebFrameLoadDelegate, NSMenuItemValidation {
    
    public var alert: NSAlert?
    public var noteLoading: ProgressState = .none
    
    public var vcEditor: EditTextView?
    public var vcTitleLabel: TitleTextField?
    public var vcNonSelectedLabel: NSTextField?
    
    public var vcPreviewButton: NSButton?
    public var vcShareButton: NSButton?
    public var vcLockUnlockButton: NSButton?
    public var vcEditorScrollView: EditorScrollView?
    
    public var previewResizeTimer = Timer()
    public var rowUpdaterTimer = Timer()
    public var editorUndoManager = UndoManager()
    
    public var breakUndoTimer = Timer()
    public var printWebView = WebView()
    
    // git
    public var snapshotsTimer = Timer()
    public var lastSnapshot: Int = 0
    public var pullTimer = Timer()
    
    public var encPassword: NSSecureTextField?
    public var encVerifyPassword: NSSecureTextField?
    public var encCompletionHandler: ((String) -> Void)?
    
    public func initView() {
        vcEditor?.delegate = self
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let vc = ViewController.shared() else { return false}
        
        // Current note
        var note = vc.editor.note
        
        if note == nil {
            note = vc.getSelectedNotes()?.first
        }
        
        let ident = menuItem.identifier?.rawValue
        
        if ident == "context.folderMenu.emptyBin" || ident == "folderMenu.emptyBin" {
            if let p = vc.sidebarOutlineView.getSelectedProject(), p.isTrash {
                menuItem.title = NSLocalizedString("Empty Trash", comment: "")
                menuItem.isHidden = false
                menuItem.isEnabled = true
                return true
            } else {
                menuItem.isHidden = true
                menuItem.isEnabled = false
                return false
            }
        }
        
        if let title = menuItem.menu?.identifier?.rawValue {
            switch title {
            case "fsnotesMenu":
                if menuItem.identifier?.rawValue == "emptyTrashMenu" {
                    menuItem.keyEquivalentModifierMask = UserDefaultsManagement.focusInEditorOnNoteSelect
                            ? [.command, .option, .shift]
                            : [.command, .shift]
                    
                    menuItem.title = NSLocalizedString("Empty Trash", comment: "")
                    return true
                }
            case "fileMenu":

                if vc.notesTableView.selectedRowIndexes.count > 1,
                   let id = menuItem.identifier?.rawValue, vc.notesTableView.limitedActionsList.contains(id) {

                    return false
                }

                if menuItem.identifier?.rawValue == "note.saveRevision"
                    || menuItem.identifier?.rawValue == "note.history" {
                    if let note = note {
                        let hasCommits = note.project.hasCommitsDiffsCache()
                        menuItem.isHidden = !hasCommits
                        return hasCommits
                    }
                }

                if menuItem.identifier?.rawValue == "fileMenu.removeEncryption" {
                    if let note = note, note.isEncrypted() {
                        menuItem.isHidden = false
                        return true
                    } else {
                        menuItem.isHidden = true
                        return false
                    }
                }
                        
                if menuItem.identifier?.rawValue == "fileMenu.print" {
                    if let note = note, note.isEncryptedAndLocked() {
                        return false
                    }
                    
                    if vc.notesTableView.selectedRowIndexes.count > 1 {
                        return false
                    }

                    if vcEditor?.note != nil {
                        return true
                    }
                }
                
                if menuItem.identifier?.rawValue == "fileMenu.newInNewWindow" {
                    return true
                }
                
                if menuItem.identifier?.rawValue == "fileMenu.rename" {
                    if let cvc = NSApplication.shared.keyWindow?.contentViewController, cvc.isKind(of: NoteViewController.self) {
                        menuItem.isHidden = true
                        return false
                    }
                    
                    menuItem.isHidden = false
                }
                
                if menuItem.identifier?.rawValue == "fileMenu.delete" {
                    guard vc.view.window?.firstResponder == vc.notesTableView,
                        let cvc = NSApplication.shared.keyWindow?.contentViewController,
                        cvc.isKind(of: ViewController.self)
                    else {
                        return false
                    }
                    
                    menuItem.keyEquivalentModifierMask =
                        UserDefaultsManagement.focusInEditorOnNoteSelect
                        ? [.command, .option]
                        : [.command]
                }

                if menuItem.identifier?.rawValue ==  "fileMenu.changeCreationDate" {
                    menuItem.title = NSLocalizedString("Change Creation Date", comment: "Menu")
                }
                
                if menuItem.identifier?.rawValue == "fileMenu.toggleContainer" {
                    if let note = note, note.container != .encryptedTextPack {
                        menuItem.title = note.container == .none
                            ? NSLocalizedString("Convert to TextBundle", comment: "")
                            : NSLocalizedString("Convert to Plain", comment: "")
                        
                        menuItem.isEnabled = true
                    } else {
                        menuItem.isEnabled = false
                    }
                }

                if menuItem.identifier?.rawValue == "fileMenu.tags" {
                    if UserDefaultsManagement.inlineTags {
                        menuItem.isHidden = true
                        return false
                    } else {
                        menuItem.isHidden = false
                    }
                }

                if menuItem.identifier?.rawValue == "fileMenu.history" {
                    if vc.notesTableView.selectedRowIndexes.count > 1 {
                        return false
                    }

                    if vcEditor?.note != nil {
                        return true
                    }
                }
                
                if menuItem.identifier?.rawValue == "fileMenu.move" {
                    if vcEditor?.note != nil {
                        return true
                    }
                }

                if menuItem.identifier?.rawValue == "fileMenu.togglePin" {
                    if let note = note {
                        menuItem.title = note.isPinned
                            ? NSLocalizedString("Unpin", comment: "")
                            : NSLocalizedString("Pin", comment: "")
                        
                        return true
                    }
                    
                    return false
                }
                
                if menuItem.identifier?.rawValue == "fileMenu.toggleLock" {
                    if let note = note {
                        menuItem.title = note.isEncryptedAndLocked()
                            ? NSLocalizedString("Unlock", comment: "")
                            : NSLocalizedString("Lock", comment: "")
                        
                        return true
                    }
                    
                    return false
                }

                if ["fileMenu.new",
                    "fileMenu.searchAndCreate",
                    "fileMenu.import"
                   ].contains(menuItem.identifier?.rawValue)
                {
                    return true
                }
                
                if menuItem.identifier?.rawValue == "fileMenu.removeOverSSH" {
                    if let note = vcEditor?.note, !note.isEncrypted(), note.uploadPath != nil || note.apiId != nil {
                       menuItem.isHidden = false
                       return true
                   } else {
                       menuItem.isHidden = true
                       return false
                   }
                }
                
                if menuItem.identifier?.rawValue == "fileMenu.uploadOverSSH" {
                    if let note = vc.editor.note, !note.isEncrypted() {
                        if note.uploadPath != nil || note.apiId != nil {
                            menuItem.title = NSLocalizedString("Update Web Page", comment: "")
                        } else {
                            menuItem.title = NSLocalizedString("Create Web Page", comment: "")
                        }
                        
                        menuItem.isHidden = false
                        
                        return true
                    } else {
                        menuItem.isHidden = true
                        
                        return false
                    }
                }
                
                if vc.notesTableView.selectedRow == -1 {
                    return false
                }

                break
            case "folderMenu":
                if menuItem.identifier?.rawValue == "folderMenu.attach" {
                    menuItem.isHidden = false
                    return true
                }

                if ident == "folderMenubar.new" || ident == "folderMenubar.new" {
                    return vc.sidebarOutlineView.validateNewFolder(menuItem: menuItem)
                }

                if ident == "folderMenu.toggleEncryption" || ident == "folderMenubar.toggleEncryption" {
                    return vc.sidebarOutlineView.validateEncryption(menuItem: menuItem)
                }

                if ident == "folderMenu.toggleLock" || ident == "folderMenubar.toggleLock" {
                    return vc.sidebarOutlineView.validateLock(menuItem: menuItem)
                }
            case "findMenu":
                if ["findMenu.find",
                    "findMenu.findAndReplace",
                    "findMenu.next",
                    "findMenu.prev"
                ].contains(menuItem.identifier?.rawValue), vc.notesTableView.selectedRow > -1 {
                    return true
                }

                return vc.editAreaScroll.isFindBarVisible || vc.editor.hasFocus()
            case "showInSidebar":
                switch menuItem.tag {
                case 1:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityInbox ? .on : .off
                case 2:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityNotes ? .on : .off
                case 3:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityTodo ? .on : .off
                case 5:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityTrash ? .on : .off
                case 6:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityUntagged ? .on : .off
                default:
                    break
                }
            case "viewMenu":
                
                switch ident {
                case "previewMathJax":
                    menuItem.state = UserDefaultsManagement.mathJaxPreview ? .on : .off
                    break
                    
                case "viewMenu.previewSoulver":
                    menuItem.state = UserDefaultsManagement.soulverPreview ? .on : .off
                    break
                    
                case "viewMenu.historyBack":
                    if vc.notesTableView.historyPosition == 0 {
                        return false
                    }
                    break
                    
                case "viewMenu.historyForward":
                    if vc.notesTableView.historyPosition == vc.notesTableView.history.count - 1 {
                        return false
                    }
                    break
                    
                case "view.toggleNoteList":
                    menuItem.title = vc.isVisibleNoteList()
                        ? NSLocalizedString("Hide Note List", comment: "")
                        : NSLocalizedString("Show Note List", comment: "")
                    break
                    
                case "view.toggleSidebar":
                    menuItem.title = vc.isVisibleSidebar()
                        ? NSLocalizedString("Hide Sidebar", comment: "")
                        : NSLocalizedString("Show Sidebar", comment: "")
                    break
                    
                case "viewMenu.actualSize":
                    return UserDefaultsManagement.fontSize != UserDefaultsManagement.DefaultFontSize

                default:
                    break
                }
                
            default:
                break
            }
        }
        
        return true
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

    @IBAction func createFolder(_ sender: Any) {
        guard let vc = ViewController.shared(),
              let sidebarOutlineView = vc.sidebarOutlineView else { return }

        // Call from menu bar
        if let sender = sender as? NSMenuItem, sender.identifier?.rawValue == "folderMenu.attach" {
            sidebarOutlineView.addRoot()
            return
        }

        // Call from popup menu or menu bar
        var project = sidebarOutlineView.getSelectedProject()

        if sender is SidebarCellView,
            let cell = sender as? SidebarCellView,
            let objectProject = cell.objectValue as? Project
        {
            project = objectProject
        }

        if project == nil {
            project = Storage.shared().getDefault()
        }

        if let project = project {
          guard let window = MainWindowController.shared() else { return }

          let alert = NSAlert()
          vc.alert = alert

          let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
          alert.messageText = NSLocalizedString("New project", comment: "")
          alert.informativeText = NSLocalizedString("Please enter project name:", comment: "")
          alert.accessoryView = field
          alert.alertStyle = .informational
          alert.addButton(withTitle: NSLocalizedString("Add", comment: ""))
          alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
          alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
              if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                  let name = field.stringValue
                  sidebarOutlineView.createProject(name: name, parent: project)
              }

              NSApp.mainWindow?.makeFirstResponder(sidebarOutlineView)
              vc.alert = nil
          }

          field.becomeFirstResponder()
        }
    }

    @IBAction func toggleFolderEncryption(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared(),
            let projects = vc.sidebarOutlineView.getSelectedProjects() else { return }

        guard let firstProject = projects.first  else { return }

        if firstProject.isEncrypted {
            vc.getMasterPassword() { password in
                vc.sidebarOutlineView.decrypt(projects: projects, password: password)
            }
        } else {
            vc.getMasterPassword(forEncrypt: true) { password in
                vc.sidebarOutlineView.encrypt(projects: projects, password: password)
            }
        }
    }

    @IBAction func toggleFolderLock(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared(),
            let projects = vc.sidebarOutlineView.getSelectedProjects() else { return }

        guard let firstProject = projects.first  else { return }

        // Lock password exist
        if firstProject.password != nil {
            vc.sidebarOutlineView.lock(projects: projects)

        // Unlock
        } else {
            let action = sender.identifier?.rawValue
            vc.getMasterPassword() { password in
                vc.sidebarOutlineView.unlock(projects: projects, password: password, action: action)
            }
        }
    }

    // MARK: Window bar actions
    
    @IBAction func toggleNotesLock(_ sender: Any) {
        guard let notes = getSelectedNotes(), let first = notes.first else { return }
        
        // Lock unlocked
        if first.isUnlocked() {
            _ = lockUnlocked(notes: notes)
            return
        }
        
        // Unlock encrypted
        if first.container == .encryptedTextPack {
            getMasterPassword() { password in
                guard password.count > 0 else { return }
                
                for note in notes {
                    guard note.isEncryptedAndLocked(), note.unLock(password: password) else { continue }
                    
                    let insertTags = note.scanContentTags().0
                    
                    DispatchQueue.main.async {
                        self.reloadAllOpenedWindows(note: note)
                        
                        ViewController.shared()?.sidebarOutlineView?.addTags(insertTags)
                        ViewController.shared()?.notesTableView.reloadRow(note: note)
                    }
                }
            }
            
            return
        }
        
        // Encrypt plain
        getMasterPassword(forEncrypt: true) { password in
            for note in notes {
                if !note.isEncrypted(), note.encrypt(password: password) {
                    note.password = nil
                    
                    DispatchQueue.main.async {
                        self.reloadAllOpenedWindows(note: note)
                        
                        ViewController.shared()?.focusTable()
                        ViewController.shared()?.notesTableView.reloadRow(note: note)
                    }
                }
            }
        }
    }
    
    @IBAction func togglePreview(_ sender: Any) {
        guard let editor = vcEditor else { return }
        
        let firstResp = view.window?.firstResponder

        editor.togglePreviewState()
        
        if (editor.isPreviewEnabled()) {
            
            //Preview mode doesn't support text search
            cancelTextSearch()
            refillEditArea(force: true)

            if let mdView = vcEditor?.editorViewController?.vcEditor?.markdownView {
                view.window?.makeFirstResponder(mdView)
            }
        } else {
            disablePreview()
        }

        if let responder = firstResp, (
            ViewController.shared()?.search.currentEditor() == firstResp
            || responder.isKind(of: NotesTableView.self)
            || responder.isKind(of: SidebarOutlineView.self)
        ) {
            view.window?.makeFirstResponder(firstResp)
        } else {
            var responder: NSResponder? = vcEditor
            
            if vcEditor?.isPreviewEnabled() == true, let mView = vcEditor?.markdownView {
                responder = mView
            }
            
            if let responder = responder {
                view.window?.makeFirstResponder(responder)
            }
        }

        vcEditor?.userActivity?.needsSave = true
        
        Storage.shared().saveNotesSettings()
    }
    
    @IBAction func toggleMathJax(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on

        UserDefaultsManagement.mathJaxPreview = sender.state == .on

        refillEditArea(force: true)
    }
    
    @IBAction func toggleSoulverCore(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on

        UserDefaultsManagement.soulverPreview = sender.state == .on

        refillEditArea(force: true)
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
        
        if let title = note.title.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {

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
        guard var notes = getSelectedNotes(),
              let vc = ViewController.shared() else { return }

        notes = decryptUnlocked(notes: notes)
        guard notes.count > 0 else { return }

        getMasterPassword() { password in
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
                
                vc.notesTableView.reloadRow(note: note)
            }
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
        
    @IBAction func createInNewWindow(_ sender: Any) {
        var content = String()
        
        if let inlineTags = ViewController.shared()?.sidebarOutlineView.getSelectedInlineTags() {
            content = inlineTags
        }
        
        if let note = createNote(content: content, openInNewWindow: true) {
            openInNewWindow(note: note)
        }
    }
    
    @IBAction func quickNote(_ sender: Any) {
        if let note = createNote(content: "", openInNewWindow: true) {
            NSApp.activate(ignoringOtherApps: true)
            
            if !NSApp.isActive {
                AppDelegate.mainWindowController?.window?.miniaturize(self)
            }
            
            openInNewWindow(note: note)
        }
    }
    
    @IBAction func historyMenu(_ sender: Any) {
        guard let cvc = NSApplication.shared.keyWindow?.contentViewController,
              let vc = ViewController.shared(),
              let note = getSelectedNotes()?.first else { return }

        let moveMenu = NSMenu()
        let commits = note.getCommits()

        // Port
        if commits.count == 0 {
            return
        }

        for commit in commits {
            let menuItem = NSMenuItem()
            menuItem.title = commit.getDate()
            menuItem.representedObject = commit
            menuItem.action = #selector(vc.checkoutRevision(_:))
            moveMenu.addItem(menuItem)
        }

        let general = moveMenu.item(at: 0)

        // Main window
        if cvc.isKind(of: ViewController.self),
           vc.notesTableView.selectedRow >= 0 {
            let view = vc.notesTableView.rect(ofRow: vc.notesTableView.selectedRow)
            let x = vc.splitView.subviews[0].frame.width + 5
            moveMenu.popUp(positioning: general, at: NSPoint(x: x, y: view.origin.y + 8), in: vc.notesTableView)
            return
        }

        // Opened in new window
        if cvc.isKind(of: NoteViewController.self) {
            moveMenu.popUp(positioning: general, at: NSPoint(x: view.frame.width + 10, y: view.frame.height - 5), in: view)
        }
    }
    
    @IBAction func duplicate(_ sender: Any) {
        guard let notes = getSelectedNotes() else { return }
        
        for note in notes {
            let src = note.url
            let dst = NameHelper.generateCopy(file: note.url)

            if note.isTextBundle() || note.isEncrypted() {
                try? FileManager.default.copyItem(at: src, to: dst)
                
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

            Storage.shared().add(noteDupe)
            ViewController.shared()?.notesTableView.insertRows(notes: [noteDupe])
        }
    }
    
    @IBAction func importNote(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.begin { (result) -> Void in
            if result == NSApplication.ModalResponse.OK {
                let urls = panel.urls
                let project = vc.sidebarOutlineView.getSelectedProject() ?? Storage.shared().getMainProject()

                for url in urls {
                    _ = vc.copy(project: project, url: url)
                }
            }
        }
    }
    
    @objc func moveNote(_ sender: NSMenuItem) {
        let project = sender.representedObject as! Project
        
        guard let notes = getSelectedNotes() else { return }
        
        ViewController.shared()?.moveReq(notes: notes, project: project) { success in
            guard success else { return }
            
            if let cvc = NSApplication.shared.keyWindow?.contentViewController,
               cvc.isKind(of: NoteViewController.self) {
                self.updateTitle(note: notes.first!)
            }
        }
    }
    
    @IBAction func toggleContainer(_ sender: NSMenuItem) {
        guard let notes = getSelectedNotes() else { return }
        
        var newContainer: NoteContainer = .textBundleV2
        if notes.first?.container == .textBundle || notes.first?.container == .textBundleV2 {
            newContainer = .none
        }
        
        for note in notes {
            if note.container == .encryptedTextPack {
                continue
            }
            
            note.convertContainer(to: newContainer)
        }
    }
    
    @IBAction func openWindow(_ sender: Any) {
        guard let currentNote = ViewController.shared()?.notesTableView.getSelectedNote() else { return }
     
        openInNewWindow(note: currentNote)
    }
    
    @IBAction func moveMenu(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        
        // Move menu right from notes table view
        
        if let cvc = NSApplication.shared.keyWindow?.contentViewController, cvc.isKind(of: ViewController.self) {
            if vc.notesTableView.selectedRow >= 0 {
                vc.loadMoveMenu()

                let moveTitle = NSLocalizedString("Move", comment: "Menu")
                let moveMenu = vc.noteMenu.item(withTitle: moveTitle)
                let view = vc.notesTableView.rect(ofRow: vc.notesTableView.selectedRow)
                let x = vc.splitView.subviews[0].frame.width + 5
                let general = moveMenu?.submenu?.item(at: 0)

                moveMenu?.submenu?.popUp(positioning: general, at: NSPoint(x: x, y: view.origin.y + 8), in: vc.notesTableView)
            }
            
            return
            
        // Move menu right from window
            
        } else {
            vc.loadMoveMenu()
            
            let moveTitle = NSLocalizedString("Move", comment: "Menu")
            let moveMenu = vc.noteMenu.item(withTitle: moveTitle)
            let general = moveMenu?.submenu?.item(at: 0)
            
            moveMenu?.submenu?.popUp(positioning: general, at: NSPoint(x: view.frame.width + 10, y: view.frame.height - 5), in: view)
        }
    }
    
    @IBAction func deleteNote(_ sender: Any) {
        var forceRemove = false

        if let menuItem = sender as? NSMenuItem,
            menuItem.identifier?.rawValue == "fileMenu.forceRemove" ||
            menuItem.identifier?.rawValue == "context.fileMenu.forceRemove" {
            forceRemove = true
        }

        guard let vc = ViewController.shared() else { return }
        guard let notes = getSelectedNotes() else { return }

        let si = vc.getSidebarItem()
        if si?.isTrash() == true || forceRemove {
            vc.removeForever()
            
            // Call from window, close it!
            if let cvc = NSApplication.shared.keyWindow?.contentViewController,
               cvc.isKind(of: NoteViewController.self) {
                DispatchQueue.main.async {
                    self.view.window?.close()
                }
            }
            
            return
        }
        
        let selectedRow = vc.notesTableView.selectedRowIndexes.min()

        UserDataService.instance.searchTrigger = true

        vc.notesTableView.removeRows(notes: notes)

        // Delete tags
        for note in notes {
            let tags = note.tags
            note.tags.removeAll()
            vc.sidebarOutlineView.removeTags(tags)
        }

        vc.storage.removeNotes(notes: notes) { urls in
            if let md = AppDelegate.mainWindowController {
                let undoManager = md.notesListUndoManager

                if let ntv = vc.notesTableView {
                    undoManager.registerUndo(withTarget: ntv, selector: #selector(ntv.unDelete), object: urls)
                    undoManager.setActionName(NSLocalizedString("Delete", comment: ""))
                }

                if let i = selectedRow, i > -1 {
                    if vc.notesTableView.noteList.count > i {
                        vc.notesTableView.selectRow(i)
                    } else {
                        vc.notesTableView.selectRow(vc.notesTableView.noteList.count - 1)
                    }
                }

                UserDataService.instance.searchTrigger = false
            }

            vc.editor.clear()
        }
        
        // Call from window, close it!
        if let cvc = NSApplication.shared.keyWindow?.contentViewController,
           cvc.isKind(of: NoteViewController.self) {
            DispatchQueue.main.async {
                self.view.window?.close()
            }
            return
        }

        // If is main window – focus to notes list
        if let cvc = NSApplication.shared.keyWindow?.contentViewController,
           cvc.isKind(of: ViewController.self) {
            NSApp.mainWindow?.makeFirstResponder(vc.notesTableView)
        }
    }

    @IBAction func actualSize(_ sender: Any) {
        UserDefaultsManagement.codeFont = NSFont(descriptor: UserDefaultsManagement.codeFont.fontDescriptor, size: CGFloat(UserDefaultsManagement.DefaultFontSize))!
        UserDefaultsManagement.noteFont = NSFont(descriptor: UserDefaultsManagement.noteFont.fontDescriptor, size: CGFloat(UserDefaultsManagement.DefaultFontSize))!

        ViewController.shared()?.reloadFonts()
    }

    @IBAction func zoomIn(_ sender: Any) {
        UserDefaultsManagement.codeFont = NSFont(descriptor: UserDefaultsManagement.codeFont.fontDescriptor, size: UserDefaultsManagement.codeFont.pointSize + 1)!
        UserDefaultsManagement.noteFont = NSFont(descriptor: UserDefaultsManagement.noteFont.fontDescriptor, size: UserDefaultsManagement.noteFont.pointSize + 1)!

        ViewController.shared()?.reloadFonts()
    }

    @IBAction func zoomOut(_ sender: Any) {
        UserDefaultsManagement.codeFont = NSFont(descriptor: UserDefaultsManagement.codeFont.fontDescriptor, size: UserDefaultsManagement.codeFont.pointSize - 1)!
        UserDefaultsManagement.noteFont = NSFont(descriptor: UserDefaultsManagement.noteFont.fontDescriptor, size: UserDefaultsManagement.noteFont.pointSize - 1)!

        ViewController.shared()?.reloadFonts()
    }

    // MARK: Dep methods
    
    public func openInNewWindow(note: Note, frame: NSRect? = nil, preview: Bool = false) {
        guard let windowController = NSStoryboard(name: "Main", bundle: nil)
            .instantiateController(withIdentifier: "noteWindowController") as? NSWindowController else { return }
        
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(windowController)
                
        let viewController = windowController.contentViewController as! NoteViewController
        viewController.initWindow()
                
        viewController.editor.changePreviewState(preview)
        viewController.editor.fill(note: note)
        
        if note.isEncryptedAndLocked() {
            viewController.toggleNotesLock(self)
        }
        
        AppDelegate.noteWindows.insert(windowController, at: 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let frame = frame {
                windowController.window?.setFrame(frame, display: true)
            }
            
            viewController.view.window?.makeFirstResponder(viewController.editor)
        }
    }
    
    func cancelTextSearch() {
        let menu = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.tag = NSTextFinder.Action.hideFindInterface.rawValue
        vcEditor?.performTextFinderAction(menu)
    }

    func disablePreview() {
        vcEditor?.disablePreviewEditorAndNote()
        
        vcEditor?.markdownView?.removeFromSuperview()
        vcEditor?.markdownView = nil
        
        guard let editor = self.vcEditor else { return }
        editor.subviews.removeAll(where: { $0.isKind(of: MPreviewView.self) })

        refillEditArea()
    }
    
    public func viewDidResize() {
        guard vcEditor?.isPreviewEnabled() == true else { return }

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
        vcPreviewButton?.state = vcEditor?.isPreviewEnabled() == true ? .on : .off

        if let note = vcEditor?.note {
            vcEditor?.fill(note: note, saveTyping: saveTyping, force: force)
        }

        noteLoading = .done
    }
    
    public func unLock(notes: [Note]) {
        getMasterPassword() { password in
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
                
                editor.window?.makeFirstResponder(editor)
            }
        }
    }

    public func getMasterPassword(forEncrypt: Bool = false, completion: @escaping (String) -> ()) {
        if #available(OSX 10.12.2, *), UserDefaultsManagement.allowTouchID {
            let context = LAContext()
            context.localizedFallbackTitle = NSLocalizedString("Enter Master Password", comment: "")

            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
                masterPasswordPrompt(validation: forEncrypt, completion: completion)
                return
            }
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "To access secure data") { (success, evaluateError) in
                
                // Skip if cancelled
                if let error = evaluateError as NSError? {
                    if error.code == LAError.userCancel.rawValue || error.code == LAError.appCancel.rawValue {
                        return
                    }
                }
                
                // Press enter password or failed TouchID
                if !success {
                    self.masterPasswordPrompt(validation: forEncrypt, completion: completion)

                    return
                }

                do {
                    let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")
                    let password = try item.readPassword()

                    completion(password)
                    return
                } catch {
                    print("Keychain error: \(error.localizedDescription)")
                }

                // No password in keychain
                self.masterPasswordPrompt(validation: forEncrypt, completion: completion)
            }
        } else {
            
            // Bio is not available or disabled
            masterPasswordPrompt(validation: forEncrypt, completion: completion)
        }
    }
    
    @IBAction func onOkClick(_ sender: Any?) {
        guard
            let passwordField = encPassword,
            let verifyPasswordField = encVerifyPassword,
            let window = self.view.window
        else { return }
        
        if passwordField.stringValue.count == 0 {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.informativeText = NSLocalizedString("Please try again", comment: "")
            alert.messageText = NSLocalizedString("Empty password", comment: "")
            alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in }
            return
        }
        
        if passwordField.stringValue != verifyPasswordField.stringValue {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.informativeText = NSLocalizedString("Please try again", comment: "")
            alert.messageText = NSLocalizedString("Wrong repeated password", comment: "")
            alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in }
            return
        }
        
        if let encCompletionHandler = encCompletionHandler {
            encCompletionHandler(passwordField.stringValue)
        }
        
        self.alert?.window.close()
    }
    
    private func masterPasswordPrompt(validation: Bool = false, completion: @escaping (String) -> ()) {
        DispatchQueue.main.async {
            guard let window = self.view.window else { return }

            self.alert = NSAlert()
            guard let alert = self.alert else { return }
            alert.alertStyle = .informational
        
            if validation {
                alert.messageText = NSLocalizedString("Enter an encryption password:", comment: "")
                
                alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
                
                alert.buttons[0].target = self
                alert.buttons[0].action = #selector(self.onOkClick(_:))

                // Create the NSTextFields and labels
                let newPasswordLabel = NSTextField(labelWithString: NSLocalizedString("Password:", comment: ""))
                let newPasswordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                let repeatPasswordLabel = NSTextField(labelWithString: NSLocalizedString("Verify Password:", comment: ""))
                let repeatPasswordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                
                self.encPassword = newPasswordField
                self.encVerifyPassword = repeatPasswordField
                self.encCompletionHandler = completion
                
                newPasswordLabel.alignment = .right
                repeatPasswordLabel.alignment = .right

                // Add the labels and text fields to a custom view
                let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 60))
                containerView.translatesAutoresizingMaskIntoConstraints = false

                newPasswordLabel.translatesAutoresizingMaskIntoConstraints = false
                newPasswordField.translatesAutoresizingMaskIntoConstraints = false
                repeatPasswordLabel.translatesAutoresizingMaskIntoConstraints = false
                repeatPasswordField.translatesAutoresizingMaskIntoConstraints = false

                containerView.addSubview(newPasswordLabel)
                containerView.addSubview(newPasswordField)
                containerView.addSubview(repeatPasswordLabel)
                containerView.addSubview(repeatPasswordField)

                // Set the custom view as the accessory view for the NSAlert
                alert.accessoryView = containerView

                // Define constraints
                NSLayoutConstraint.activate([
                    newPasswordLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
                    newPasswordLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
                    newPasswordField.leadingAnchor.constraint(equalTo: newPasswordLabel.trailingAnchor, constant: 8),
                    newPasswordField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 0),
                    newPasswordField.widthAnchor.constraint(equalToConstant: 200),
                    newPasswordField.centerYAnchor.constraint(equalTo: newPasswordLabel.centerYAnchor),

                    repeatPasswordLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
                    repeatPasswordLabel.topAnchor.constraint(equalTo: newPasswordLabel.bottomAnchor, constant: 8),
                    repeatPasswordField.leadingAnchor.constraint(equalTo: repeatPasswordLabel.trailingAnchor, constant: 8),
                    repeatPasswordField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 0),
                    repeatPasswordField.widthAnchor.constraint(equalToConstant: 200),
                    repeatPasswordField.centerYAnchor.constraint(equalTo: repeatPasswordLabel.centerYAnchor),

                    containerView.widthAnchor.constraint(equalToConstant: 400),
                    containerView.heightAnchor.constraint(equalToConstant: 60),
                ])

                // Show the NSAlert
                alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
                    self.alert = nil
                }

                newPasswordField.becomeFirstResponder()
                return
            }
            
            let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
            alert.accessoryView = field
            alert.messageText = NSLocalizedString("Master password:", comment: "")
            alert.informativeText = NSLocalizedString("Please enter password for current note", comment: "")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    completion(field.stringValue)
                }

                self.alert = nil
            }

            field.becomeFirstResponder()
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
              !editor.isPreviewEnabled() || note.isRTF(),
            note.container != .encryptedTextPack
        else { return }

        editor.window?.makeFirstResponder(editor)

        if let ntv = ViewController.shared()?.notesTableView, ntv.selectedRow > -1 {
            vcEditor?.isEditable = true
            vcNonSelectedLabel?.isHidden = true
        }
    }
        
    // Changed main edit view
    func textDidChange(_ notification: Notification) {
        guard let editor = vcEditor,
              let note = editor.note,
              let vc = ViewController.shared() else { return }

        vc.prevCommit = nil

        if editor.isEditable {
            editor.removeHighlight()
            editor.saveImages()

            note.save(attributed: editor.attributedString())

            updateLastEditedStatus()
            vc.reSort(note: note)
        }

        breakUndoTimer.invalidate()
        breakUndoTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(breakUndo), userInfo: nil, repeats: true)
    }

    private func updateLastEditedStatus() {
        let editors = AppDelegate.getEditTextViews()

        for editor in editors {
            editor.isLastEdited = false
        }

        vcEditor?.isLastEdited = true
    }
            
    @objc func breakUndo() {
        guard let editor = vcEditor else { return }
        
        if (
            editor.isPreviewEnabled() == false
           && editor.isEditable
        ) {
            editor.breakUndoCoalescing()
        }
    }
    
    public func createNote(name: String = "", content: String = "", type: NoteType? = nil, project: Project? = nil, load: Bool = false, openInNewWindow: Bool = false) -> Note? {
        
        guard let vc = ViewController.shared() else { return nil }

        let selectedProjects = vc.sidebarOutlineView.getSidebarProjects()
        var sidebarProject = project ?? selectedProjects?.first
        var text = content
        
        if let type = vc.getSidebarType(), type == .Todo, content.count == 0 {
            text = "- [ ] "
        }
        
        if sidebarProject == nil {
            sidebarProject = Storage.shared().getDefault()
        }
        
        guard let project = sidebarProject else { return nil }

        let note = Note(name: name, project: project, type: type)
        note.content = NSMutableAttributedString(string: text)
        note.save()

        _ = note.scanContentTags()

        if let selectedProjects = selectedProjects, !selectedProjects.contains(project) {
            return note
        }

        if !openInNewWindow {
            disablePreview()
            
            vc.notesTableView.deselectNotes()
            vc.editor.string = text
            vc.editor.note = note
            vc.search.stringValue.removeAll()
        }
        
        vc.updateTable() {
            if openInNewWindow {
                return
            }
            
            DispatchQueue.main.async {
                vc.notesTableView.saveNavigationHistory(note: note)
                if let index = vc.notesTableView.getIndex(note) {
                    vc.notesTableView.selectRowIndexes([index], byExtendingSelection: false)
                    vc.notesTableView.scrollRowToVisible(index)
                }
            
                vc.focusEditArea()
            }
        }
        
        // Project encrypted and unlocked – encrypt by default
        if let password = project.password {
            if note.encrypt(password: password) {
                if note.unLock(password: password) {
                    note.password = password
                }
            }
        }

        return note
    }
}
