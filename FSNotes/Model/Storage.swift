//
//  NotesCollection.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/9/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Marklight
import Highlightr
import CloudKit

class Storage {
    static let instance = Storage()
    
    var noteList = [Note]()
    var notesDict: [String: Note] = [:]
    
    static var generalUrl: URL?
    static var pinned: Int = 0
    static var allowedExtensions = ["md", "markdown", "txt", "rtf", UserDefaultsManagement.storageExtension]
    
    func loadDocuments() {
        noteList.removeAll()
        
        let storageItemList = CoreDataManager.instance.fetchStorageList()
        
        for item in storageItemList {
            loadLabel(item)
        }

        if let list = sortNotes(noteList: noteList) {
            noteList = list
        }
        
        guard !checkFirstRun() else {
            return
        }
        
        guard UserDefaultsManagement.codeBlockHighlight else {
            return
        }
        
        cacheMarkdown()
    }
    
    func sortNotes(noteList: [Note]?) -> [Note]? {
        guard let list = noteList else {
            return nil
        }
        
        let sortDirection = UserDefaultsManagement.sortDirection
        
        switch UserDefaultsManagement.sort {
        case .CreationDate:
            return list.sorted(by: {
                if $0.isPinned == $1.isPinned, let prevDate = $0.creationDate, let nextDate = $1.creationDate {
                    return sortDirection && prevDate > nextDate || !sortDirection && prevDate < nextDate
                }
                return $0.isPinned && !$1.isPinned
            })
        
        case .ModificationDate:
            return list.sorted(by: {
                if $0.isPinned == $1.isPinned, let prevDate = $0.modifiedLocalAt, let nextDate = $1.modifiedLocalAt {
                    return sortDirection && prevDate > nextDate || !sortDirection && prevDate < nextDate
                }
                return $0.isPinned && !$1.isPinned
            })
        
        case .Title:
            return list.sorted(by: {
                if $0.isPinned == $1.isPinned {
                    return sortDirection && $0.title < $1.title || !sortDirection && $0.title > $1.title
                }
                return $0.isPinned && !$1.isPinned
            })
        }
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
            
            note.creationDate = document.2
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
    
    func readDirectory(_ url: URL) -> [(URL, Date, Date)] {
        do {
            let directoryFiles =
                try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey], options:.skipsHiddenFiles)
            
            return
                directoryFiles.filter {Storage.allowedExtensions.contains($0.pathExtension)}.map{
                    url in (
                        url,
                        (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                            )?.contentModificationDate ?? Date.distantPast,
                        (try? url.resourceValues(forKeys: [.creationDateKey])
                            )?.creationDate ?? Date.distantPast
                    )
                }
        } catch {
            print("Storage not found, url: \(url)")
        }
        
        return []
    }
    
    func add(_ note: Note) {
        if !noteList.contains(where: { $0.name == note.name && $0.storage == note.storage }) {
           noteList.append(note)
        }
    }
    
    func removeBy(note: Note) {
        if let i = noteList.index(of: note) {
            noteList.remove(at: i)
        }
    }
    
    func remove(id: Int) {
        noteList[id].isRemoved = true
    }
    
    func getNextId() -> Int {
        return noteList.count
    }
    
    func checkFirstRun() -> Bool {
        let destination = Storage.instance.getBaseURL()
        let path = destination.path
        
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("General storage not found")
            }
        }
        
        guard noteList.isEmpty else {
            return false
        }
        
        let srcHello = Bundle.main.url(forResource: "Hello world", withExtension: "md")
        let srcCode = Bundle.main.url(forResource: "Code highlighting sample", withExtension: "md")
        
        let dstHello = URL(fileURLWithPath: path + "/Hello world.md")
        let dstCode = URL(fileURLWithPath: path + "/Code highlighting sample.md")
        
        do {
            try FileManager.default.copyItem(at: srcHello!, to: dstHello)
            try FileManager.default.copyItem(at: srcCode!, to: dstCode)
        } catch {
            print("Initial copy error: \(error)")
        }
        
        return true
    }
    
    func getOrCreate(name: String) -> Note {
        var note: Note?
        
        note = noteList.first(where: {
            return ($0.name == name && $0.isGeneral())
        })
        
        if note == nil {
            note = Note(context: CoreDataManager.instance.context)
            note?.name = name
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
    
    func getBaseURL() -> URL {
        if let gu = Storage.generalUrl {
            return gu
        }
        
        guard let storage = CoreDataManager.instance.fetchGeneralStorage(), let path = storage.path, let url = URL(string: path) else {
            return UserDefaultsManagement.storageUrl
        }
        
        Storage.generalUrl = url
        
        return url
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
    
    func cacheMarkdown() {
        DispatchQueue.global(qos: .background).async {
            let markdownDocuments = self.noteList.filter{
                $0.isMarkdown()
            }
            
            for note in markdownDocuments {
                note.markdownCache()
            }
        }
    }
    
    func removeNotes(notes: [Note], completion: @escaping () -> Void) {
        guard notes.count > 0 else {
            return
        }
        
        for note in notes {
            removeBy(note: note)
        }
        
        #if CLOUDKIT
            if UserDefaultsManagement.cloudKitSync {
                var recordIds: [CKRecordID] = []
                
                for note in notes {
                    if let record = CKRecord(archivedData: note.cloudKitRecord) {
                        recordIds.append(record.recordID)
                    }
                }
                
                CloudKitManager.instance.removeRecords(records: recordIds) {
                    CoreDataManager.instance.removeNotes(notes: notes)
                    completion()
                }
            } else {
                CoreDataManager.instance.removeNotes(notes: notes)
                completion()
            }
        #else
            CoreDataManager.instance.removeNotes(notes: notes)
            completion()
        #endif
    }
    
    func saveNote(note: Note, userInitiated: Bool = false) {
        add(note)
        
        guard note.isGeneral() else {
            return
        }
        
        note.loadModifiedLocalAt()
        
        #if CLOUDKIT
            if UserDefaultsManagement.cloudKitSync {
                if userInitiated {
                    NotificationsController.onStartSync()
                }
                
                // save state to core database
                note.isSynced = false
                CoreDataManager.instance.save()
                
                // save cloudkit
                CloudKitManager.instance.saveNote(note)
            }
        #endif
    }
    
    func removeNote(note: Note) {
        let name = note.name
        removeBy(note: note)
        
        guard note.isGeneral() else {
            return
        }
        
        note.isRemoved = true
        #if CLOUDKIT
            if UserDefaultsManagement.cloudKitSync {
                CloudKitManager.instance.removeRecord(note: note)
            }
        #else
            CoreDataManager.instance.remove(note)
            print("Removed successfully: \(name)")
        #endif
    }
}
