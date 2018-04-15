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
    private var projects = [Project]()
    
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
    
    private var bookmarks = [URL]()
    
    init() {
        #if CLOUDKIT
        if let cloudDriveURL = getCloudDrive() {
            let project = Project(url: cloudDriveURL, label: "iCloud Drive", isRoot: true)
            add(project: project)
        }
        #endif
        
        // FSNotes container, when iCloud Drive disabled 
        if projects.count == 0, let local = getLocalURL() {
            let project = Project(url: local, label: "Local", isRoot: true)
            add(project: project)
        }
        
        let bookmark = SandboxBookmark.sharedInstance()
        bookmarks = bookmark.load()
        
        for url in bookmarks {
            guard !projectExist(url: url) else {
                continue
            }
            
            let project = Project(url: url, label: url.lastPathComponent, isRoot: true)
            add(project: project)
        }
    }
    
    public func getChildProjects(project: Project) -> [Project] {
        return projects.filter({ $0.parent == project })
    }
    
    public func getRootProjects() -> [Project] {
        return projects.filter({ $0.isRoot })
    }
    
    private func chechSub(url: URL, parent: Project) {
        if let subFolders = getSubFolders(url: url) {
            for subFolder in subFolders {
                let surl = subFolder as URL
                print(surl.path)
                guard !projectExist(url: surl), surl.lastPathComponent != "i", !surl.path.contains(".Trash"),
                    !surl.path.contains("/.") else {
                    continue
                }
                
                let project = Project(url: surl, label: surl.lastPathComponent, parent: parent)
                projects.append(project)
            }
        }
    }
    
    private func checkTrashForVolume(url: URL) {
        guard let trashURL = getTrash(url: url) else {
            return
        }
        
        guard !projectExist(url: trashURL) else {
            return
        }
        
        let project = Project(url: trashURL, isTrash: true)
        projects.append(project)
    }
    
    private func getCloudDrive() -> URL? {
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            
            var isDirectory = ObjCBool(true)
            if FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return iCloudDocumentsURL
            }
        }
        
        return nil
    }
    
    private func getLocalURL() -> URL? {
        guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return nil
        }
        
        return URL(fileURLWithPath: path)
    }
        
    func projectExist(url: URL) -> Bool {
        return projects.contains(where: {$0.url == url})
    }
    
    public func removeBy(project: Project) {
        let list = noteList.filter({ $0.project ==
            project })
        
        for note in list {
            if let i = noteList.index(of: note) {
                noteList.remove(at: i)
            }
        }
        
        if let i = projects.index(of: project) {
            projects.remove(at: i)
        }
    }
    
    public func add(project: Project) {
        projects.append(project)
        
        if project.isRoot {
            chechSub(url: project.url, parent: project)
            checkTrashForVolume(url: project.url)
        }
    }
    
    func getTrash(url: URL) -> URL? {
        return try? FileManager.default.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: url, create: false)
    }
    
    public func getBookmarks() -> [URL] {
        return bookmarks
    }
    
    public static func sharedInstance() -> Storage {
        guard let storage = self.instance else {
            self.instance = Storage()
            return self.instance!
        }
        return storage
    }
    
    func loadDocuments(tryCount: Int = 0) {
        noteList.removeAll()
        
        for project in projects {
            loadLabel(project)
        }
        
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
    
    public func getProjects() -> [Project] {
        return projects
    }
    
    public func getCloudDriveProjects() -> [Project] {
        return projects.filter({$0.isCloudDrive == true})
    }
    
    public func getLocalProjects() -> [Project] {
        return projects.filter({$0.isCloudDrive == false})
    }
    
    public func getProjectPaths() -> [String] {
        var pathList: [String] = []
        let projects = getProjects()
        
        for project in projects {
            pathList.append(NSString(string: project.url.path).expandingTildeInPath)
        }
        
        return pathList
    }
    
    public func getProjectBy(url: URL) -> Project? {
        let projectURL = url.deletingLastPathComponent()
        
        return
            projects.first(where: {
                return (
                    $0.url == projectURL
                )
            })
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
    
    func loadLabel(_ item: Project) {
        let keyStore = NSUbiquitousKeyValueStore()
        let documents = readDirectory(item.url)

        for document in documents {
            let url = document.0
            let note = Note(url: url)
            note.parseURL()
            let name = url.pathComponents.last!
            
            if (url.pathComponents.count == 0) {
                continue
            }
            
            note.modifiedLocalAt = document.1
            note.creationDate = document.2
            note.project = item
            
            #if CLOUDKIT
                note.isPinned = keyStore.bool(forKey: name)
            #else
                let data = try? note.url.extendedAttribute(forName: "co.fluder.fsnotes.pin")
                let isPinned = data?.withUnsafeBytes { (ptr: UnsafePointer<Bool>) -> Bool in
                    return ptr.pointee
                }
            
                if let pin = isPinned {
                    note.isPinned = pin
                }
            #endif
            
            note.load(url)
            if note.isPinned {
                pinned += 1
            }
            
            noteList.append(note)
        }
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
        if !noteList.contains(where: { $0.name == note.name && $0.project == note.project }) {
           noteList.append(note)
        }
    }
    
    func removeBy(note: Note) {
        if let i = noteList.index(where: {$0 === note}) {
            noteList.remove(at: i)
        }
    }
    
    func getNextId() -> Int {
        return noteList.count
    }
    
    func checkFirstRun() -> Bool {
        guard noteList.isEmpty, let resourceURL = Bundle.main.resourceURL else { return false }
        guard let destination = getDemoSubdirURL() else { return false }
        
        let initialPath = resourceURL.appendingPathComponent("Initial").path
        let path = destination.path
        
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
    
    func getDemoSubdirURL() -> URL? {
#if os(OSX)
        if let project = projects.first {
            let pURL = project.url.appendingPathComponent("FSNotes")
            
            do {
                try FileManager.default.createDirectory(at: pURL, withIntermediateDirectories: false, attributes: nil)
            } catch {
                return nil
            }
            
            let childProject = Project(url: pURL, parent: project)
            add(project: childProject)
            
            return pURL
        }
        
        return nil
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
                
                guard let currentNote = EditTextView.note else {
                    continue
                }
                
                if note.url == currentNote.url {
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
        
        if fsRemove {
            for note in notes {
                note.removeFile()
            }
        }
        
        completion()
    }
        
    func getSubFolders(url: URL) -> [NSURL]? {
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
    
    public func getCurrentProject() -> Project? {
        return projects.first
    }
}
