//
//  NotesCollection.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/9/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Highlightr

class Storage {
    static var instance: Storage? = nil
    
    var noteList = [Note]()
    var notesDict: [String: Note] = [:]
    var generalUrl: URL?
    
    var allowedExtensions = ["md", "markdown", "txt", "rtf", "fountain", UserDefaultsManagement.storageExtension]
    
    var pinned: Int = 0
    
#if os(iOS)
    let initialFiles = [
        "FSNotes - Readme.md",
        "FSNotes - Code Highlighting.md"
    ]
#else
    let initialFiles = [
        "FSNotes - Readme.md",
        "FSNotes - Release Notes.md",
        "FSNotes - Shortcuts.md",
        "FSNotes - Code Highlighting.md"
    ]
#endif
    
    public static func sharedInstance() -> Storage {
        guard let storage = self.instance else {
            self.instance = Storage()
            return self.instance!
        }
        return storage
    }
    
    func loadDocuments(tryCount: Int = 0) {
        noteList.removeAll()
        
        let storageItemList = CoreDataManager.instance.fetchStorageList()
        
        for item in storageItemList {
            loadLabel(item)
        }
        
        /* subfolders support
        if let generalSubFolders = getGeneralSubFolders() {
            for item in generalSubFolders {
                if let storage = storageItemList.filter({ $0.getUrl() == item as? URL }).first {
                    //loadLabel(storage)
                } else {
                    let storageItem = StorageItem(context: CoreDataManager.instance.context)
                    storageItem.path = item.absoluteString
                    storageItem.label = item.lastPathComponent
                    CoreDataManager.instance.save()
                    loadLabel(storageItem)
                }
            }
        }
        */
 
        if let list = sortNotes(noteList: noteList) {
            noteList = list
        }
        
        guard !checkFirstRun() else {
            if tryCount == 0 {
                loadDocuments(tryCount: 1)
                return
            }
            
            #if os(OSX)
                cacheMarkdown()
            #endif
            return
        }
        
        #if os(OSX)
            cacheMarkdown()
        #endif
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
        let keyStore = NSUbiquitousKeyValueStore()
        
        guard let url = item.getUrl() else {
            return
        }
        
        let documents = readDirectory(url)
        let existNotes = CoreDataManager.instance.fetchAll()
        
        for note in existNotes {
            var path: String = ""
            if let storage = note.storage, let unwrappedPath = storage.path {
                path = unwrappedPath
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
            
            #if CLOUDKIT
                note.isPinned = keyStore.bool(forKey: name)
            #endif
            
            note.load(url)
            
            if !note.isSynced {
                note.modifiedLocalAt = date
            }
            
            if note.isPinned {
                pinned += 1
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
                directoryFiles.filter {
                    allowedExtensions.contains($0.pathExtension)}.map{
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
    
    func getNextId() -> Int {
        return noteList.count
    }
    
    func checkFirstRun() -> Bool {
        let destination = getBaseURL()
        let path = destination.path
        
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("General storage not found: \(error)")
            }
        }
        
        guard noteList.isEmpty, let resourceURL = Bundle.main.resourceURL else {
            return false
        }
        
        let initialPath = resourceURL.appendingPathComponent("Initial").path
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: initialPath)
            for file in files {
                guard initialFiles.contains(file) else {
                    continue
                }
                try? FileManager.default.copyItem(atPath: "\(initialPath)/\(file)", toPath: "\(path)/\(file)")
            }
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
            CoreDataManager.instance.context.insert(note!)
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
                    $0.url.path.lowercased() == url.path.lowercased()
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
    
    func getBy(title: String) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.title == title
                )
            })
    }
    
    func getBy(startWith: String) -> [Note]? {
        return
            noteList.filter{
                $0.title.starts(with: startWith)
            }
    }
    
    func getBaseURL() -> URL {
#if os(OSX)
        if let gu = generalUrl {
            return gu
        }
    
        guard let storage = CoreDataManager.instance.fetchGeneralStorage(), let path = storage.path, let url = URL(string: path) else {
            return UserDefaultsManagement.storageUrl
        }
    
        generalUrl = url
        return url
#else
        return UserDefaultsManagement.documentDirectory
#endif
    }
            
    var isActiveCaching = false
    var terminateBusyQueue = false
    
    func cacheMarkdown() {
        guard !self.isActiveCaching else {
            self.terminateBusyQueue = true
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            self.isActiveCaching = true
            
            let markdownDocuments = self.noteList.filter{
                $0.isMarkdown()
            }
            
            for note in markdownDocuments {
                note.markdownCache()
                
                if note == EditTextView.note {
                #if os(OSX)
                    let viewController = NSApplication.shared.windows.first!.contentViewController as! ViewController
                    viewController.refillEditArea()
                #else
                    DispatchQueue.main.async {
                        guard
                            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
                            let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
                            let evc = viewController.viewControllers[0] as? EditorViewController else {
                            return
                        }
                        
                        evc.fill(note: note)
                    }
                #endif
                }
                
                if self.terminateBusyQueue {
                    print("Caching data obsolete, restart caching initiated.")
                    self.terminateBusyQueue = false
                    self.isActiveCaching = false
                    self.loadDocuments()
                    break
                }
            }
            
            self.isActiveCaching = false
        }
    }
    
    func removeNotes(notes: [Note], fsRemove: Bool = true, completion: @escaping () -> Void) {
        guard notes.count > 0 else {
            completion()
            return
        }
        
        for note in notes {
            removeBy(note: note)
        }
        
        CoreDataManager.instance.removeNotes(notes: notes, fsRemove: fsRemove)
        completion()
    }
    
    func saveNote(note: Note, userInitiated: Bool = false, cloudSync: Bool = true) {
        add(note)
    }
    
    func getGeneralSubFolders() -> [NSURL]? {
        guard let storage = CoreDataManager.instance.fetchGeneralStorage(), let url = storage.getUrl() else { return nil }
        
        guard let fileEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions()) else { return nil }
        
        var subdirs = [NSURL]()
        
        while let url = fileEnumerator.nextObject() as? NSURL {
            do {
                var resourceValue: AnyObject?
                try url.getResourceValue(&resourceValue, forKey: URLResourceKey.isDirectoryKey)
                if let isDirectory = resourceValue as? Bool, isDirectory == true {
                    subdirs.append(url)
                }
            }
            catch let error as NSError {
                print("Error: ", error.localizedDescription)
            }
        }
        
        return subdirs
    }
}
