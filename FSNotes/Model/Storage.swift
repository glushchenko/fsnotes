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
    static var allowedExtensions = ["md", "markdown", "txt", "rtf", UserDefaultsManagement.storageExtension]
    
    func loadDocuments() {
        let storageItemList = CoreDataManager.instance.fetchStorageList()
        
        for item in storageItemList {
            loadLabel(item)
        }
        
        Swift.print(noteList.isEmpty)
        if (noteList.isEmpty) {
            createHelloWorld()
        }
    }
    
    func loadLabel(_ item: StorageItem) {
        guard let url = item.getUrl() else {
            return
        }
        
        let documents = readDirectory(url)
        let existNotes = CoreDataManager.instance.fetchAll()
        var notesDict: [String: Note] = [:]
        
        for note in existNotes {
            notesDict[note.name] = note
        }
        
        for document in documents {
            var note: Note
            
            let url = document.0
            let date = document.1
            let name = url.pathComponents.last!
            
            if (url.pathComponents.count == 0) {
                continue
            }
            
            if notesDict[name] == nil {
                note = CoreDataManager.instance.make()
                note.isSynced = false
            } else {
                note = notesDict[name]!
                note.checkLocalSyncState(date)
            }
            
            note.load(url)
            
            if !note.isSynced {
                note.modifiedLocalAt = date
            }
            
            if note.isPinned {
                Storage.pinned += 1
            }
            
            noteList.append(note)
        }
        
        CoreDataManager.instance.save()
    }
    
    func readDirectory(_ url: URL) -> [(URL, Date)] {
        return
            try! FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options:.skipsHiddenFiles
            ).filter {
                Storage.allowedExtensions.contains($0.pathExtension)
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
            let note = getOrCreate(name: "Hello world.md")
            note.url = destination
            note.extractUrl()
            note.content = try String(contentsOf: initialDoc!)
            note.save()
            
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
    
    func getBy(name: String) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.name == name
                )
            })
    }

}
