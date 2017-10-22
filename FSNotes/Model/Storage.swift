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
    static var pinned: Int = 0
    
    func loadDocuments() {
        var documents = readDirectory()
        
        if (documents.isEmpty) {
            createHelloWorld()
            let helloUrl = UserDefaultsManagement.storageUrl.appendingPathComponent("Hello world.md")
            let helloDate = (try? helloUrl.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            documents.append((helloUrl, helloDate))
        }
        
        let existNotes = CoreDataManager.instance.fetchAll()
        
        for document in documents {
            let url = document.0
            let date = document.1
            let name = url.pathComponents.last!
            
            if (url.pathComponents.count == 0) {
                continue
            }
            
            var note: Note
            if !existNotes.contains(where: { $0.name == name }) {
                note = CoreDataManager.instance.make()
                note.isSynced = false
            } else {
                note = existNotes.first(where: { $0.name == name })!
                note.checkLocalSyncState(date)
            }

            note.load(url)
            CoreDataManager.instance.save()
            
            if note.isPinned {
                Storage.pinned += 1
            }
            
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
    
    func add(_ note: Note) {
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
        
        let note = CoreDataManager.instance.make()
        add(note)
        return note
    }
    
    func getModified() -> Note? {
        return
            noteList.first(where: {
                return (
                    !$0.isSynced
                )
            })
    }
    
    func getBy(url: URL) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.url == url
                )
            })
    }

}
