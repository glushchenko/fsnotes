//
//  ViewController+Menu.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 16.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import AppKit

extension ViewController {
    
    func processFileMenuItems(_ menuItem: NSMenuItem, menuId: String) -> Bool {
        
        // Submenu
        if menuItem.menu?.identifier?.rawValue == "fileMenu.move" ||
            menuItem.menu?.identifier?.rawValue == "fileMenu.history" {
            return true
        }
        
        guard let vc = ViewController.shared(),
              let evc = NSApplication.shared.keyWindow?.contentViewController as? EditorViewController,
              let id = menuItem.identifier?.rawValue else { return false }
                        
        let isFirstResponder = evc.view.window?.firstResponder?.isKind(of: NotesTableView.self) == true
        let isOpenedWindow = NSApplication.shared.keyWindow?.contentViewController?.isKind(of: NoteViewController.self) == true
        
        let notes = vc.getSelectedNotes()
        let greaterThanZero = notes?.isEmpty == false
        let isOne = notes?.count == 1
        
        func hasEncrypted(notes: [Note]? = nil) -> Bool {
            guard let notes = notes else { return false }
            return notes.contains { $0.isEncrypted() && !$0.project.isEncrypted }
        }
        
        switch id {
        case "\(menuId).close":
            menuItem.title = NSLocalizedString("Close", comment: "File Menu")
            return true
            
        case "\(menuId).import":
            menuItem.title = NSLocalizedString("Import", comment: "File Menu")
            return true
            
        case "\(menuId).new":
            menuItem.title = NSLocalizedString("New Note", comment: "File Menu")
            return true
            
        case "\(menuId).newInNewWindow":
            menuItem.title = NSLocalizedString("New Note in New Window", comment: "File Menu")
            return true
            
        case "\(menuId).searchAndCreate":
            menuItem.title = NSLocalizedString("Search and Create", comment: "File Menu")
            return true
            
        case "\(menuId).open":
            menuItem.title = NSLocalizedString("Open Note in New Window", comment: "File Menu")
            return greaterThanZero
            
        case "\(menuId).duplicate":
            menuItem.title = NSLocalizedString("Duplicate", comment: "File Menu")
            return greaterThanZero && isFirstResponder
            
        case "\(menuId).rename":
            menuItem.title = NSLocalizedString("Rename", comment: "File Menu")
            return isOne && isFirstResponder
            
        case "\(menuId).delete":
            menuItem.title = NSLocalizedString("Delete", comment: "File Menu")
            return greaterThanZero && isFirstResponder
            
        case "\(menuId).forceDelete":
            menuItem.title = NSLocalizedString("Force Delete", comment: "File Menu")
            return greaterThanZero && isFirstResponder
            
        case "\(menuId).togglePin":
            if let note = notes?.first, note.isPinned {
                menuItem.title = NSLocalizedString("Unpin", comment: "File Menu")
            } else {
                menuItem.title = NSLocalizedString("Pin", comment: "File Menu")
            }
            return greaterThanZero
            
        case "\(menuId).decrypt":
            menuItem.title = NSLocalizedString("Decrypt", comment: "File Menu")
            return greaterThanZero && hasEncrypted(notes: notes)
            
        case "\(menuId).toggleLock":
            if let note = notes?.first, note.isEncryptedAndLocked() {
                menuItem.title = NSLocalizedString("Unlock", comment: "File Menu")
            } else {
                menuItem.title = NSLocalizedString("Lock", comment: "File Menu")
            }
            return greaterThanZero && (isFirstResponder || isOpenedWindow)
            
        case "\(menuId).external":
            menuItem.title = NSLocalizedString("Open External", comment: "File Menu")
            return greaterThanZero
            
        case "\(menuId).reveal":
            menuItem.title = NSLocalizedString("Reveal in Finder", comment: "File Menu")
            return greaterThanZero && (isFirstResponder || isOpenedWindow)
            
        case "\(menuId).date":
            menuItem.title = NSLocalizedString("Change Creation Date", comment: "File Menu")
            return greaterThanZero && (isFirstResponder || isOpenedWindow)
            
        case "\(menuId).toggleContainer":
            if let note = notes?.first, note.container == .none {
                menuItem.title = NSLocalizedString("Convert to TextBundle", comment: "")
            } else {
                menuItem.title =  NSLocalizedString("Convert to Plain", comment: "")
            }
            return greaterThanZero && !hasEncrypted(notes: notes) && (isFirstResponder || isOpenedWindow)
            
        case "\(menuId).copyURL":
            menuItem.title = NSLocalizedString("Copy URL", comment: "File Menu")
            return isOne && (isFirstResponder || isOpenedWindow)
            
        case "\(menuId).copyTitle":
            menuItem.title = NSLocalizedString("Copy Title", comment: "File Menu")
            return isOne && (isFirstResponder || isOpenedWindow)
            
        case "\(menuId).uploadOverSSH":
            if let note = notes?.first, note.uploadPath != nil || note.apiId != nil {
                menuItem.title = NSLocalizedString("Update Web Page", comment: "File Menu")
            } else {
                menuItem.title = NSLocalizedString("Create Web Page", comment: "File Menu")
            }
            return isOne && (isFirstResponder || isOpenedWindow)
            
        case "\(menuId).removeOverSSH":
            menuItem.title = NSLocalizedString("Delete Web Page", comment: "File Menu")
            if let note = notes?.first {
                return (isFirstResponder || isOpenedWindow) && isOne && !note.isEncrypted() && (note.uploadPath != nil || note.apiId != nil)
            }
            
        case "\(menuId).move":
            menuItem.title = NSLocalizedString("Move", comment: "File Menu")
            return greaterThanZero && (isFirstResponder || isOpenedWindow)
            
        case "\(menuId).history":
            menuItem.title = NSLocalizedString("History", comment: "File Menu")
            if let note = notes?.first {
                return isOne && (isFirstResponder || isOpenedWindow) && note.project.hasCommitsDiffsCache()
            }
            
        case "\(menuId).print":
            menuItem.title = NSLocalizedString("Print", comment: "File Menu")
            return isOne && (isFirstResponder || isOpenedWindow)
        default:
            break
        }
        
        return false
    }
    
    func processLibraryMenuItems(_ menuItem: NSMenuItem, menuId: String) -> Bool {
        guard let vc = ViewController.shared(),
              let id = menuItem.identifier?.rawValue else { return false }

        let tags = vc.sidebarOutlineView.getSidebarTags()
        let projects = vc.sidebarOutlineView.getSelectedProjects()
        
        let projectSelected = projects?.isEmpty == false
        let tagSelected = tags?.isEmpty == false
        
        let isFirstResponder = view.window?.firstResponder?.isKind(of: SidebarOutlineView.self) == true
        let isTrash = vc.sidebarOutlineView.getSidebarItems()?.first?.type == .Trash
        
        switch id {
        case "\(menuId).attach":
            menuItem.title = NSLocalizedString("Add External Folder...", comment: "Menu Library")
            return true
        case "\(menuId).backup":
            var title = NSLocalizedString("Inbox", comment: "")
            
            if let gitProject = vc.getGitProject() {
                title = gitProject.label
                
                if gitProject.isDefault {
                    title = NSLocalizedString("Inbox", comment: "")
                }
                
                menuItem.title =  String(format: NSLocalizedString("Commit & Push “%@”", comment: "Menu Library"), title)
                return true
            }
            
            return false
            
        case "\(menuId).create":
            menuItem.title = NSLocalizedString("Create Folder", comment: "Menu Library")
            return !isTrash
            
        case "\(menuId).rename":
            if tagSelected {
                menuItem.title = NSLocalizedString("Rename Tag", comment: "Menu Library")
            } else {
                menuItem.title = NSLocalizedString("Rename Folder", comment: "Menu Library")
            }
            return isFirstResponder && (projectSelected || tagSelected)
            
        case "\(menuId).delete":
            if let project = projects?.first, project.isBookmark {
                menuItem.title = NSLocalizedString("Detach Storage", comment: "Menu Library")
            } else if tagSelected {
                menuItem.title = NSLocalizedString("Delete Tag", comment: "Menu Library")
            } else {
                menuItem.title = NSLocalizedString("Delete Folder", comment: "Menu Library")
            }
            return isFirstResponder && (projectSelected || tagSelected)
            
        case "\(menuId).decrypt":
            menuItem.title = NSLocalizedString("Decrypt Folder", comment: "Menu Library")
            if let project = projects?.first, !project.isTrash, !project.isDefault, !project.isVirtual, project.isEncrypted {
                return isFirstResponder
            }
            
        case "\(menuId).toggleLock":
            if let project = projects?.first, !project.isTrash, project.isLocked() {
                menuItem.title = NSLocalizedString("Unlock Folder", comment: "")
            } else {
                menuItem.title = NSLocalizedString("Lock Folder", comment: "Menu Library")
            }
            return isFirstResponder && projectSelected
            
        case "\(menuId).reveal":
            menuItem.title = NSLocalizedString("Reveal in Finder", comment: "Menu Library")
            return isFirstResponder && projectSelected
            
        case "\(menuId).options":
            menuItem.title = NSLocalizedString("Show Options", comment: "Menu Library")
            return isFirstResponder && projectSelected
        default:
            break
        }
        
        return false
    }
        
    func loadMoveMenu() {
        guard let vc = ViewController.shared(), let note = vc.notesTableView.getSelectedNote() else { return }
        
        let moveTitle = NSLocalizedString("Move", comment: "Menu")
        if let prevMenu = noteMenu.item(withTitle: moveTitle) {
            noteMenu.removeItem(prevMenu)
        }
        
        let moveMenuItem = NSMenuItem()
        moveMenuItem.title = NSLocalizedString("Move", comment: "Menu")
        
        noteMenu.addItem(moveMenuItem)
        let moveMenu = NSMenu()
        moveMenu.identifier = NSUserInterfaceItemIdentifier("fileMenu.move")

        if UserDefaultsManagement.inlineTags, let tagsMenu = noteMenu.item(withTitle: NSLocalizedString("Tags", comment: "")) {
            noteMenu.removeItem(tagsMenu)
        }
        
        if !note.isTrash() {
            let trashMenu = NSMenuItem()
            trashMenu.title = NSLocalizedString("Trash", comment: "Sidebar label")
            trashMenu.action = #selector(vc.deleteNote(_:))
            trashMenu.tag = 555
            moveMenu.addItem(trashMenu)
            moveMenu.addItem(NSMenuItem.separator())
        }
                
        let projects = storage.getSortedProjects()
        for item in projects {
            if note.project == item || item.isTrash {
                continue
            }
            
            let menuItem = NSMenuItem()
            menuItem.title = item.getNestedLabel()
            menuItem.representedObject = item
            menuItem.action = #selector(vc.moveNote(_:))
            moveMenu.addItem(menuItem)
        }

        noteMenu.setSubmenu(moveMenu, for: moveMenuItem)
        loadHistory()
    }
    
    public func loadHistory() {
        guard let vc = ViewController.shared(),
            let notes = vc.notesTableView.getSelectedNotes(),
            let note = notes.first
        else { return }

        let title = NSLocalizedString("History", comment: "")
        let historyMenu = noteMenu.item(withTitle: title)
        historyMenu?.submenu?.removeAllItems()
        historyMenu?.isEnabled = false
        historyMenu?.isHidden = !note.project.hasCommitsDiffsCache()

        guard notes.count == 0x01 else { return }

        DispatchQueue.global().async {
            let commits = note.getCommits()

            DispatchQueue.main.async {
                guard commits.count > 0 else {
                    historyMenu?.isEnabled = false
                    return
                }
                
                for commit in commits {
                    let menuItem = NSMenuItem()
                    menuItem.title = commit.getDate()
                    menuItem.representedObject = commit
                    menuItem.action = #selector(vc.checkoutRevision(_:))
                    historyMenu?.submenu?.addItem(menuItem)
                }
                
                historyMenu?.isEnabled = true
            }
        }
    }
}
