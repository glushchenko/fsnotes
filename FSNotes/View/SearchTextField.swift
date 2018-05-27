//
//  SearchTextField.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/3/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Carbon.HIToolbox

class SearchTextField: NSTextField, NSTextFieldDelegate {

    public var vcDelegate: ViewController!
    
    private var filterQueue = OperationQueue.init()
    private var searchTimer = Timer()
    
    public var allowAutocomplete = true
    public var searchQuery = ""
    public var selectedRange = NSRange()
    
    override func draw(_ dirtyRect: NSRect) {
        delegate = self
        super.draw(dirtyRect)
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
        focusRingType = .none
    }
    
    override func keyUp(with event: NSEvent) {
        if (event.keyCode == kVK_DownArrow) {
            vcDelegate.focusTable()
            vcDelegate.notesTableView.selectNext()
            return
        }
        
        if (event.keyCode == kVK_LeftArrow) {
            vcDelegate.storageOutlineView.window?.makeFirstResponder(vcDelegate.storageOutlineView)
            vcDelegate.storageOutlineView.selectRowIndexes([1], byExtendingSelection: false)
            return
        }
        
        if event.keyCode == kVK_Return {
            vcDelegate.focusEditArea()
        }
    }
 
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if (
            event.keyCode == kVK_Escape
            || (
                [kVK_ANSI_L, kVK_ANSI_N].contains(Int(event.keyCode))
                && event.modifierFlags.contains(.command)
            )
        ) {
            allowAutocomplete = true
            searchQuery = ""
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    public func suggestAutocomplete(_ note: Note) {
        if note.title == stringValue {
            return
        }
        
        searchQuery = stringValue
        
        if allowAutocomplete && note.title.lowercased().starts(with: searchQuery.lowercased()) {
            stringValue = note.title
            currentEditor()?.selectedRange = NSRange(searchQuery.utf16.count..<note.title.utf16.count)
            allowAutocomplete = false
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector.description {
        case "cancelOperation:":
            allowAutocomplete = true
            return true
        case "deleteBackward:":
            allowAutocomplete = false
            textView.deleteBackward(self)
            return true
        case "insertNewline:":
            if let note = vcDelegate.editArea.getSelectedNote(), stringValue.count > 0, note.title.lowercased().starts(with: searchQuery.lowercased()) {
                vcDelegate.focusEditArea()
            } else {
                vcDelegate.makeNote(self)
            }
            return true
        case "insertTab:":
            vcDelegate.focusEditArea()
            vcDelegate.editArea.scrollToCursor()
            return true
        case "deleteWordBackward:":
            textView.deleteWordBackward(self)
            return true
        default:
            return false
        }
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        UserDataService.instance.searchTrigger = true
        
        filterQueue.cancelAllOperations()
        filterQueue.addOperation {
            DispatchQueue.main.async {
                self.vcDelegate.updateTable(search: true) {
                    self.allowAutocomplete = true
                    if UserDefaultsManagement.focusInEditorOnNoteSelect {
                        self.searchTimer.invalidate()
                        self.searchTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1), target: self, selector: #selector(self.onEndSearch), userInfo: nil, repeats: false)
                    } else {
                        UserDataService.instance.searchTrigger = false
                    }
                }
            }
        }
    }
    
    @objc func onEndSearch() {
        UserDataService.instance.searchTrigger = false
    }

}
