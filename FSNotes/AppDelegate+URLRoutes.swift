//
//  AppDelegate+URLRoutes.swift
//  FSNotes
//
//  Created by Jeff Hanbury on 13/04/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Cocoa


extension AppDelegate {
    
    enum Routes: String {
        case find = "find"
        case new = "new"
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
            let directive = url.host
            else { return }
        
        switch directive {
        case Routes.find.rawValue:
            RouteHandlerForFind(url)
        case Routes.new.rawValue:
            RouteHandlerForNew(url)
        default:
            break
        }
    }

    /// Handles URLs with the path /find/title
    func RouteHandlerForFind(_ url: URL) {
        let name = url.lastPathComponent
        if let note = storage.getBy(title: name),
            let window = NSApplication.shared.windows.first,
            let controller = window.contentViewController as? ViewController {
            controller.updateTable(filter: name) {
                controller.notesTableView.setSelected(note: note)
            }
        }
    }
    
    /// Handles URLs with the path /new/note-name/encoded-note-contents
    func RouteHandlerForNew(_ url: URL) {
        let pathComponents = url.pathComponents
        let noteTitle = pathComponents[1]
        let noteBody = pathComponents[2]

        guard let window = NSApplication.shared.windows.first,
            let controller = window.contentViewController as? ViewController
            else { return }
        
        controller.createNote(name: noteTitle, content: noteBody)
    }
}
