//
//  MainWindowController.swift
//  FSNotes
//
//  Created by BUDDAx2 on 8/9/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import AppKit


class MainWindowController: NSWindowController, NSWindowDelegate {
    let notesListUndoManager = UndoManager()
    var editorUndoManager = UndoManager()
    
    override func windowDidLoad() {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.mainWindowController = self
        self.window?.hidesOnDeactivate = UserDefaultsManagement.hideOnDeactivate
        self.window?.titleVisibility = .hidden
    }
    
    func windowDidResize(_ notification: Notification) {
        refreshEditArea()
    }
        
    func makeNew() {
        window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
        refreshEditArea()
    }
    
    func refreshEditArea() {
        let controller = NSApplication.shared.windows.first?.contentViewController as? ViewController
        controller?.focusEditArea()
    }
    
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        guard let fr = window.firstResponder else {
            return notesListUndoManager
        }
        
        if fr.isKind(of: NotesTableView.self) {
            return notesListUndoManager
        }
        
        if fr.isKind(of: EditTextView.self) {
            guard let vc = NSApp.windows[0].contentViewController as? ViewController, let ev = vc.editArea, ev.isEditable else { return notesListUndoManager }
            
            return editorUndoManager
        }
        
        return notesListUndoManager
    }
}
