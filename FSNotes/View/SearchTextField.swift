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
    private var searchTimer = Timer()

    public var searchQuery = ""
    public var selectedRange = NSRange()
    public var skipAutocomplete = false

    public var timestamp: Int64?
    private var lastQueryLength: Int = 0
    private var lastQuery = String()

    override func textDidEndEditing(_ notification: Notification) {
        if let editor = self.currentEditor(), editor.selectedRange.length > 0 {
            skipAutocomplete = true
            editor.replaceCharacters(in: editor.selectedRange, with: "")
            window?.makeFirstResponder(nil)
        }

        lastQuery = String()
    }

    override func keyUp(with event: NSEvent) {
        if (event.keyCode == kVK_DownArrow) {
            vcDelegate.focusTable()
            vcDelegate.notesTableView.selectNext()
            return
        }
        
        if (event.keyCode == kVK_LeftArrow && stringValue.count == 0) {
            vcDelegate.storageOutlineView.window?.makeFirstResponder(vcDelegate.storageOutlineView)
            vcDelegate.storageOutlineView.selectRowIndexes([1], byExtendingSelection: false)
            return
        }
        
        if event.keyCode == kVK_Return {
            vcDelegate.focusEditArea()
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
            return true
        case "cancelOperation:":
            return true
        case "deleteBackward:":
            self.skipAutocomplete = true
            self.lastQuery = String()
            textView.deleteBackward(self)
            return true
        case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
            if let note = vcDelegate.editArea.getSelectedNote(), stringValue.count > 0, note.title.lowercased() == stringValue.lowercased() || note.fileName.lowercased() == stringValue.lowercased() {

                if note.title.lowercased() == stringValue.lowercased() && note.title != stringValue {
                    stringValue = note.title
                }

                if note.fileName.lowercased() == stringValue.lowercased() && note.fileName != stringValue {
                    stringValue = note.fileName
                }

                markCompleteonAsSuccess()
                vcDelegate.focusEditArea()
            } else {
                vcDelegate.makeNote(self)
            }

            searchTimer.invalidate()
            return true
        case "insertTab:":
            markCompleteonAsSuccess()
            vcDelegate.focusEditArea()
            vcDelegate.editArea.scrollToCursor()
            return true
        case "deleteWordBackward:":
            textView.deleteWordBackward(self)
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
        search()
    }
    
    public func suggestAutocomplete(_ note: Note, filter: String) {
        guard note.title != filter.lowercased(), let editor = currentEditor() else { return }

        if note.title.lowercased().starts(with: filter.lowercased()) {
            stringValue = filter + note.title.suffix(note.title.count - filter.count)
            lastQuery = stringValue
            editor.selectedRange = NSRange(filter.utf16.count..<note.title.utf16.count)
            return
        }

        if note.fileName.lowercased().starts(with: filter.lowercased()) {
            stringValue = filter + note.fileName.suffix(note.fileName.count - filter.count)
            lastQuery = stringValue
            editor.selectedRange = NSRange(filter.utf16.count..<note.fileName.utf16.count)
            return
        }

        lastQuery = String()
    }

    @objc private func search() {
        UserDataService.instance.searchTrigger = true

        let searchText = self.stringValue
        let currentTextLength = searchText.count
        var sidebarItem: SidebarItem? = nil

        if let location = currentEditor()?.selectedRange.location, !skipAutocomplete {
            if lastQuery.startsWith(string: stringValue) {
                let range = NSRange(location: location, length: lastQuery.count - location)
                stringValue = lastQuery
                currentEditor()?.selectedRange = range
                return
            }
        }

        if currentTextLength > self.lastQueryLength {
            self.skipAutocomplete = false
        }

        self.lastQueryLength = searchText.count

        let projects = vcDelegate.storageOutlineView.getSidebarProjects()
        let tags = vcDelegate.storageOutlineView.getSidebarTags()

        if projects == nil && tags == nil {
            sidebarItem = self.vcDelegate.getSidebarItem()
        }

        self.filterQueue.cancelAllOperations()
        self.filterQueue.addOperation {
            self.vcDelegate.updateTable(search: true, searchText: searchText, sidebarItem: sidebarItem, projects: projects, tags: tags) {
                if !UserDefaultsManagement.focusInEditorOnNoteSelect {
                    UserDataService.instance.searchTrigger = false
                }

                if !self.skipAutocomplete {
                    if let note = self.vcDelegate.notesTableView.noteList.first {
                        DispatchQueue.main.async {
                            if let searchQuery = self.getSearchTextExceptCompletion() {
                                self.suggestAutocomplete(note, filter: searchQuery)
                            }
                        }
                    }
                }
            }
        }

        let pb = NSPasteboard(name: .findPboard)
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
    }
}
