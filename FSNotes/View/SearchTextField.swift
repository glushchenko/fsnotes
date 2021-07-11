//
//  SearchTextField.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/3/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Carbon.HIToolbox

import FSNotesCore_macOS

class SearchTextField: NSSearchField, NSSearchFieldDelegate {

    public var vcDelegate: ViewController!
    
    private var filterQueue = OperationQueue.init()

    public var searchQuery = ""
    public var selectedRange = NSRange()
    public var skipAutocomplete = false

    public var timestamp: Int64?
    private var lastQueryLength: Int = 0
    private var lastQuery = String()

    public var searchesMenu: NSMenu? = nil

    public func generateRecentMenu() -> NSMenu {
        let menu = NSMenu(title: "Recents")
        menu.autoenablesItems = true

        if let recent = UserDefaultsManagement.recentSearches, recent.count > 0 {
            menu.addItem(withTitle: "Recents Search", action: nil, keyEquivalent: "")

            var i = 1
            for title in recent {
                let menuItem = NSMenuItem(title: title, action: #selector(selectRecent(_:)), keyEquivalent: String(i))
                menuItem.target = self
                menu.addItem(menuItem)
                i += 1
            }

            menu.addItem(NSMenuItem.separator())

            let menuItem = NSMenuItem(title: "Clear", action: #selector(cleanRecents(_:)), keyEquivalent: "d")
            menuItem.target = self
            menu.addItem(menuItem)

            return menu
        }

        menu.addItem(withTitle: "No Recent Search", action: nil, keyEquivalent: "")

        return menu
    }

    override func textDidEndEditing(_ notification: Notification) {
        if let editor = self.currentEditor(), editor.selectedRange.length > 0 {
            editor.replaceCharacters(in: editor.selectedRange, with: "")
            window?.makeFirstResponder(nil)
        }

        self.skipAutocomplete = false
        self.lastQuery = String()
        self.lastQueryLength = 0

        addRecent(query: stringValue)
    }

    override func keyUp(with event: NSEvent) {
        if (event.keyCode == kVK_DownArrow) {
            vcDelegate.focusTable()
            vcDelegate.notesTableView.selectNext()
            return
        }
        
        if (event.keyCode == kVK_LeftArrow && stringValue.count == 0) {
            vcDelegate.sidebarOutlineView.window?.makeFirstResponder(vcDelegate.sidebarOutlineView)

            let index = vcDelegate.sidebarOutlineView.selectedRowIndexes.count > 0
                ? vcDelegate.sidebarOutlineView.selectedRowIndexes
                : [0]

            vcDelegate.sidebarOutlineView.selectRowIndexes(index, byExtendingSelection: false)
            return
        }

        if event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete {
            self.skipAutocomplete = true
            return
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector.description {
        case "moveDown:":
            if let editor = currentEditor() {
                let query = editor.string.prefix(editor.selectedRange.location)
                if query.count == 0 {
                    return false
                }
                self.stringValue = String(query)
            }

            addRecent(query: stringValue)

            return true
        case "cancelOperation:":
            self.skipAutocomplete = true
            self.lastQuery = String()
            self.filterQueue.cancelAllOperations()
            return true
        case "deleteBackward:":
            self.skipAutocomplete = true
            self.lastQuery = String()
            self.filterQueue.cancelAllOperations()
            textView.deleteBackward(self)
            return true
        case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
            if let note = vcDelegate.editArea.getSelectedNote(), stringValue.utf16.count > 0, note.title.lowercased() == stringValue.lowercased() || note.fileName.lowercased() == stringValue.lowercased() {

                if note.title.lowercased() == stringValue.lowercased() && note.title != stringValue {
                    stringValue = note.title
                }

                if note.fileName.lowercased() == stringValue.lowercased() && note.fileName != stringValue {
                    stringValue = note.fileName
                }

                markCompleteonAsSuccess()

                if vcDelegate.currentPreviewState == .on
                    && EditTextView.note?.container != .encryptedTextPack {
                    vcDelegate.currentPreviewState = .off
                    DispatchQueue.main.async {
                        self.vcDelegate.refillEditArea()
                        NSApp.mainWindow?.makeFirstResponder(self.vcDelegate.editArea)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.vcDelegate.focusEditArea()
                    }
                }
            } else {
                vcDelegate.makeNote(self)
            }

            addRecent(query: stringValue)

            return true
        case "insertTab:":
            markCompleteonAsSuccess()

            if vcDelegate.currentPreviewState == .on {
                NSApp.mainWindow?.makeFirstResponder(vcDelegate.editArea.markdownView)
            } else {
                vcDelegate.focusEditArea()
            }

            vcDelegate.editArea.scrollToCursor()
            return true
        case "deleteWordBackward:":
            self.skipAutocomplete = true
            self.lastQuery = String()
            self.filterQueue.cancelAllOperations()
            textView.deleteWordBackward(self)
            lastQueryLength = self.stringValue.utf16.count
            return true
        case "noop:":
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.command) && event.keyCode == kVK_Return {
                vcDelegate.makeNote(self)
                return true
            }
            return false
        default:
            return false
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        vcDelegate.restoreCurrentPreviewState()
        
        search()
    }
    
    public func suggestAutocomplete(_ note: Note, filter: String) {
        guard note.title.lowercased() != filter.lowercased(),
            let editor = currentEditor()
        else { return }

        if note.title.lowercased().starts(with: filter.lowercased()) {

            if note.title.lowercased() != stringValue.lowercased() {
                stringValue = filter + String(note.title.utf16.suffix(note.title.utf16.count - filter.utf16.count))!
                lastQuery = stringValue
                lastQueryLength = stringValue.utf16.count
            }

            editor.selectedRange = NSRange(filter.utf16.count..<note.title.utf16.count)
            return
        }

        if note.fileName.lowercased().starts(with: filter.lowercased()) {

            if note.fileName.lowercased() != stringValue.lowercased() {
                stringValue = filter + String(note.fileName.utf16.suffix(note.fileName.utf16.count - filter.utf16.count))!
                lastQuery = stringValue
                lastQueryLength = stringValue.utf16.count
            }

            editor.selectedRange = NSRange(filter.utf16.count..<note.fileName.utf16.count)
            return
        }

        lastQuery = stringValue
    }

    @objc private func search() {
        UserDataService.instance.searchTrigger = true

        let searchText = self.stringValue
        let currentTextLength = searchText.count
        var sidebarItem: SidebarItem? = nil

        if !skipAutocomplete {
            let safeLength = lastQuery.dropFirst(stringValue.count).utf16.count
            let safeLocation = lastQuery.prefix(stringValue.count).utf16.count

            if lastQuery.startsWith(string: stringValue) {
                let range = NSRange(location: safeLocation, length: safeLength)
                stringValue = lastQuery
                currentEditor()?.selectedRange = range
            }
        }

        if currentTextLength > self.lastQueryLength {
            self.skipAutocomplete = false
        }

        self.lastQueryLength = searchText.count

        let projects = vcDelegate.sidebarOutlineView.getSidebarProjects()
        let tags = vcDelegate.sidebarOutlineView.getSidebarTags()

        if projects == nil && tags == nil {
            sidebarItem = self.vcDelegate.getSidebarItem()
        }

        self.filterQueue.cancelAllOperations()
        self.filterQueue.addOperation {
            self.vcDelegate.updateTable(search: true, searchText: searchText, sidebarItem: sidebarItem, projects: projects, tags: tags) {
                if !self.skipAutocomplete, let note = self.vcDelegate.notesTableView.noteList.first {
                    DispatchQueue.main.async {
                        if let searchQuery = self.getSearchTextExceptCompletion() {
                            self.suggestAutocomplete(note, filter: searchQuery)
                        }
                    }
                }
            }
        }

        let pb = NSPasteboard(name: NSPasteboard.Name.find)
        pb.declareTypes([.textFinderOptions, .string], owner: nil)
        pb.setString(searchText, forType: NSPasteboard.PasteboardType.string)
    }

    private func getSearchTextExceptCompletion() -> String? {
        guard let editor = currentEditor() else { return nil }

        if editor.selectedRange.location > 0 {
            return String(editor.string.suffix(editor.selectedRange.location))
        }

        return nil
    }

    private func markCompleteonAsSuccess() {
        currentEditor()?.selectedRange = NSRange(location: stringValue.count, length: 0)

        self.skipAutocomplete = false
        self.lastQuery = String()
        self.lastQueryLength = 0
    }

    @IBAction public func selectRecent(_ sender: NSMenuItem) {
        stringValue = sender.title

        vcDelegate.restoreCurrentPreviewState()
        search()
    }

    @IBAction public func cleanRecents(_ sender: NSMenuItem) {
        UserDefaultsManagement.recentSearches = nil
        searchesMenu = generateRecentMenu()
    }

    public func addRecent(query: String) {
        let query = query.trim()

        guard query.trim().count > 0 else { return }

        var recents = UserDefaultsManagement.recentSearches ?? [String]()

        if recents.contains(query) {
            if let index = recents.firstIndex(of: query) {
                recents.remove(at: index)
            }
        }
        
        recents.insert(query, at: 0)

        if recents.count > 9 {
            recents = recents.dropLast()
        }

        UserDefaultsManagement.recentSearches = recents
        searchesMenu = generateRecentMenu()
    }
}
