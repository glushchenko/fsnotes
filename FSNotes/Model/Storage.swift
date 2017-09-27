//
//  NotesCollection.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/9/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class Storage {
    static let instance = Storage()
    
    var noteList = [Note]()
    var i: Int = 0
    static var pinned: Int = 0
    
    func loadFiles() {
        var documents = readDirectory()
        
        if (documents.isEmpty) {
            createHelloWorld()
            let helloUrl = UserDefaultsManagement.storageUrl.appendingPathComponent("Hello world.md")
            let helloDate = (try? helloUrl.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            documents.append((helloUrl, helloDate))
        }
        
        let existNotes = CoreDataManager.instance.fetchNotes()
        
        for document in documents {
            let url = document.0
            let date = document.1
            let name = url
                .deletingPathExtension()
                .pathComponents
                .last!
            
            print(name)
            //print(url.deletingPathExtension().pathComponents.last!)
            
            if (url.pathComponents.count == 0) {
                continue
            }
            
            var note: Note
            if !existNotes.contains(where: { $0.name == name }) {
                note = CoreDataManager.instance.createNote()
                note.isSynced = false
                
                print("saved \(note.name)")
            } else {
                note = existNotes.first(where: { $0.name == name })!
                note.checkLocalSyncState(date)
            }

            note.modifiedLocalAt = date
            note.url = url
            note.extractUrl()
            note.load()
            note.loadModifiedLocalAt()
            note.id = i
            CoreDataManager.instance.saveContext()
            
            if note.isPinned {
                Storage.pinned += 1
            }
            
            i += 1
            
            noteList.append(note)
        }
    }
    
    func readDirectory() -> [(URL, Date)] {
        let directory = UserDefaultsManagement.storageUrl
        let defaultExtension = UserDefaultsManagement.storageExtension
        let allowedExtensions = ["md", "markdown", "txt", "rtf", defaultExtension]
        
        return
            try! FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options:.skipsHiddenFiles
            ).filter {
                allowedExtensions.contains($0.pathExtension)
            }.map { url in (
                    url,
                    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                )
            }
            .sorted(by: { $0.1 > $1.1 })
    }
    
    func add(note: Note) {
        noteList.append(note)
    }
    
    func remove(id: Int) {
        noteList[id].isRemoved = true
    }
    
    func getNextId() -> Int {
        return noteList.count
    }
    
    func createHelloWorld() {
        let initialDoc = Bundle.main.url(forResource: "Hello world", withExtension: "md")
        var destination = UserDefaultsManagement.storageUrl
        destination.appendPathComponent("Hello world.md")
        
        do {
            try FileManager.default.copyItem(at: initialDoc!, to: destination)
        } catch {
            print("Initial copy error: \(error)")
        }
    }
    
    func getOrCreate(name: String) -> Note {
        let list = noteList.filter() {
            return ($0.name == name)
        }
        if list.count > 0 {
            return list.first!
        }
        
        let note = CoreDataManager.instance.createNote()
        add(note: note)
        return note
    }
    
    func getModifiedLatestThen() -> [Note] {
        return
            noteList.filter() {
                return (
                    !$0.isSynced
                )
        }
    }

}
