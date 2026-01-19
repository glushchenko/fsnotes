//
//  Proect.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 08.01.2026.
//  Copyright © 2026 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

extension Project {
    public func saveModificationTime() {
        let dbUrl = url.appendingPathComponent(".mtime")
        var content = String()
        
        guard let projects = getAllChild() else { return }
        for project in projects {
            let notes = project.getNotes()
            for note in notes {
                content += note.modifiedLocalAt.ISO8601Format() + " " +  note.getRelatedPath() + "\n"
            }
        }
        
        try? FileManager.default.removeItem(at: dbUrl)
        try? content.write(to: dbUrl, atomically: true, encoding: .utf8)
    }

    public func saveCreationTime() {
        let dbUrl = url.appendingPathComponent(".ctime")
        var content = String()
        
        guard let projects = getAllChild() else { return }
        for project in projects {
            let notes = project.getNotes()
            for note in notes {
                if let date = note.creationDate {
                    content += date.ISO8601Format() + " " +  note.getRelatedPath() + "\n"
                }
            }
        }
        
        try? FileManager.default.removeItem(at: dbUrl)
        try? content.write(to: dbUrl, atomically: true, encoding: .utf8)
    }
}
