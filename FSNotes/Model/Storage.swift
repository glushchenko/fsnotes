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
    var notesDict: [String: Note] = [:]
    
    static var pinned: Int = 0
    static var allowedExtensions = ["md", "markdown", "txt", "rtf", UserDefaultsManagement.storageExtension]
    
    func loadDocuments() {
        noteList.removeAll()
        
        let storageItemList = CoreDataManager.instance.fetchStorageList()
        
        for item in storageItemList {
            loadLabel(item)
        }

        if (noteList.isEmpty) {
            createHelloWorld()
        }
        
        if let list = sortNotes(noteList: noteList) {
            noteList = list
        }
    }
    
    func sortNotes(noteList: [Note]?) -> [Note]? {
        return noteList?.sorted(by: {
            if $0.isPinned == $1.isPinned, let prevDate = $0.modifiedLocalAt, let nextDate = $1.modifiedLocalAt {
                return prevDate > nextDate
            }
            return $0.isPinned && !$1.isPinned
        })
    }
    
    func loadLabel(_ item: StorageItem) {
        guard let url = item.getUrl() else {
            return
        }
        
        let documents = readDirectory(url)
        let existNotes = CoreDataManager.instance.fetchAll()
        
        for note in existNotes {
            var path = ""
            if let storage = note.storage {
                path = storage.path!
            }
            notesDict[note.name + path] = note
        }
        
        for document in documents {
            var note: Note
            
            let url = document.0
            let date = document.1
            let name = url.pathComponents.last!
            let uniqName = name + item.path!
            
            if (url.pathComponents.count == 0) {
                continue
            }
            
            if notesDict[uniqName] == nil {
                note = CoreDataManager.instance.make()
                note.isSynced = false
            } else {
                note = notesDict[uniqName]!
                note.checkLocalSyncState(date)
            }
            
            note.storage = item
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
            }.map {
                url in (
                    url, (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    )?.contentModificationDate ?? Date.distantPast
                )
            }
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
        var destination = Storage.instance.getGeneralURL()
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
        var note: Note?
        
        note = noteList.first(where: {
            return ($0.name == name && $0.isGeneral())
        })
        
        if note == nil {
            note = Note(context: CoreDataManager.instance.context)
            add(note!)
        }
        
        return note!
    }
    
    func getModified() -> Note? {
        return
            noteList.first(where: {
                return (
                    !$0.isSynced && $0.isGeneral()
                )
            })
    }
    
    func getBy(url: URL) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.url == url
                    && $0.isGeneral()
                )
            })
    }
    
    func getBy(name: String) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.name == name && $0.isGeneral()
                )
            })
    }
    
    func getGeneralURL() -> URL {
        let path = CoreDataManager.instance.fetchGeneralStorage()?.path
        
        return URL(string: path!)!
    }
    
    func countSynced() -> Int {
        return
            noteList.filter{
                !$0.cloudKitRecord.isEmpty
                && $0.isGeneral()
                && $0.isSynced
            }.count
    }
    
    func countTotal() -> Int {
        return
            noteList.filter{
                $0.isGeneral()
            }.count
    }

}
