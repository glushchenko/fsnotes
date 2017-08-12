//
//  NotesCollection.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/9/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class Storage {
    var noteList = [Note]()
    var filterList = [Note]()
    var i: Int = 0
    
    func loadFiles() {
        let markdownFiles = readDocuments()
        
        for (markdownPath) in markdownFiles {
            let url = UserDefaultsManagement.storageUrl.appendingPathComponent(markdownPath)
            
            var name = ""
            if (url.pathComponents.count > 0) {
                name = url.pathComponents.last!
            }
            
            let note = Note()
            note.name = name
            note.url = url
            note.load()
            note.id = i
            
            i += 1
            
            noteList.append(note)
        }
    }
    
    func readDocuments() -> Array<String> {
        let urlArray = [String]()
        let directory = UserDefaultsManagement.storageUrl
        
        if let urlArray = try? FileManager.default.contentsOfDirectory(at: directory,
                                                                       includingPropertiesForKeys: [.contentModificationDateKey],
                                                                       options:.skipsHiddenFiles) {
            
            let allowedExtensions = [
                "md",
                "txt",
                "rtf",
                UserDefaultsManagement.storageExtension
            ]
            
            let markdownFiles = urlArray.filter {
                allowedExtensions.contains($0.pathExtension)
            }
            
            return markdownFiles.map { url in
                (
                    url.lastPathComponent,
                    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast)
                }
                .sorted(by: { $0.1 > $1.1 })
                .map { $0.0 }
        }
        
        return urlArray
    }
    
    func add(note: Note) {
        noteList.append(note)
    }
    
    func remove(id: Int) {
        noteList[id].isRemoved = true
    }
    
    func get(id: Int) -> Note {
        let note = noteList[id]
        return note
    }
    
    func getNextId() -> Int {
        i += 1
        return i
    }

}
