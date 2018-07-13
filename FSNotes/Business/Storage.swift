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
    private var imageFolders = [URL]()
    public var tagNames = [String]()
    
    var notesDict: [String: Note] = [:]
    var generalUrl: URL?
    
    var allowedExtensions = ["md", "markdown", "txt", "rtf", "fountain", UserDefaultsManagement.storageExtension, "textbundle"]
    
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
        let bookmark = SandboxBookmark.sharedInstance()
        bookmarks = bookmark.load()
        
        guard let url = UserDefaultsManagement.storageUrl else { return }
        
        var name = url.lastPathComponent
        if let iCloudURL = getCloudDrive(), iCloudURL == url {
            name = "iCloud Drive"
        }
        
        let project = Project(url: url, label: name, isRoot: true, isDefault: true)
        _ = add(project: project)
        
        for url in bookmarks {
            guard !projectExist(url: url) else {
                continue
            }
            
            if url == UserDefaultsManagement.archiveDirectory {
                continue
            }
            
            let project = Project(url: url, label: url.lastPathComponent, isRoot: true)
            _ = add(project: project)
        }
        
        let archiveLabel = NSLocalizedString("Archive", comment: "Sidebar label")
        
        if let archive = UserDefaultsManagement.archiveDirectory {
            let project = Project(url: archive, label: archiveLabel, isRoot: false, isDefault: false, isArchive: true)
            _ = add(project: project)
        }
    }
    
    public func getChildProjects(project: Project) -> [Project] {
        return projects.filter({ $0.parent == project }).sorted(by: { $0.label.lowercased() < $1.label.lowercased() })
    }
    
    public func getRootProjects() -> [Project] {
        return projects.filter({ $0.isRoot && $0.url != UserDefaultsManagement.archiveDirectory }).sorted(by: { $0.label.lowercased() < $1.label.lowercased() })
    }
    
    private func chechSub(url: URL, parent: Project) -> [Project] {
        var added = [Project]()
        let parentPath = url.path + "/i/"
        
        if let subFolders = getSubFolders(url: url) {
            for subFolder in subFolders {
                if subFolder as URL == UserDefaultsManagement.archiveDirectory {
                    continue
                }
                
                if subFolder.lastPathComponent == "i" {
                    self.imageFolders.append(subFolder as URL)
                    continue
                }
                
                if projects.count > 100 {
                    return added
                }
                
                let surl = subFolder as URL
                
                guard !projectExist(url: surl),
                    surl.lastPathComponent != "i",
                    !surl.path.contains(".Trash"),
                    !surl.path.contains("/."),
                    !surl.path.contains(parentPath),
                    !surl.path.contains(".textbundle") else {
                    continue
                }
                
                let project = Project(url: surl, label: surl.lastPathComponent, parent: parent)
                projects.append(project)
                added.append(project)
            }
        }
        
        return added
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
    
    public func add(project: Project) -> [Project] {
        var added = [Project]()
        projects.append(project)
        added.append(project)
        
        if project.isRoot && project.url != UserDefaultsManagement.archiveDirectory {
            let addedSubProjects = chechSub(url: project.url, parent: project)
            added = added + addedSubProjects
            checkTrashForVolume(url: project.url)
        }
        
        return added
    }
    
    public func getArchive() -> Project? {
        if let project = projects.first(where: { $0.isArchive }) {
            return project
        }
        
        return nil
    }
    
    func getTrash(url: URL) -> URL? {
        #if os(OSX)
            return try? FileManager.default.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: url, create: false)
        #endif
        
        if #available(iOS 11.0, *) {
            return try? FileManager.default.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: url, create: false)
        } else {
            return nil
        }
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
        
        if let list = sortNotes(noteList: noteList, filter: "") {
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
        
    func sortNotes(noteList: [Note]?, filter: String) -> [Note]? {
        var searchQuery = ""
        if filter.count > 0 {
            searchQuery = filter.lowercased()
        }
        
        guard let list = noteList else {
            return nil
        }
        
        return list.sorted(by: {
            if filter.count > 0 && $0.title.lowercased().starts(with: searchQuery) {
                if $0.title.lowercased().starts(with: searchQuery) && $1.title.lowercased().starts(with: searchQuery) {
                    return sortQuery(note: $0, next: $1)
                }
                
                return true
            }
            
            return sortQuery(note: $0, next: $1)
        })
    }
    
    private func sortQuery(note: Note, next: Note) -> Bool {
        let sortDirection = UserDefaultsManagement.sortDirection
        
        if note.isPinned == next.isPinned {
            switch UserDefaultsManagement.sort {
            case .CreationDate:
                if let prevDate = note.creationDate, let nextDate = next.creationDate {
                    return sortDirection && prevDate > nextDate || !sortDirection && prevDate < nextDate
                }
            case .ModificationDate:
                return sortDirection && note.modifiedLocalAt > next.modifiedLocalAt || !sortDirection && note.modifiedLocalAt < next.modifiedLocalAt
            case .Title:
                return sortDirection && note.title.lowercased() < next.title.lowercased() || !sortDirection && note.title.lowercased() > next.title.lowercased()
            }
        }
        
        return note.isPinned && !next.isPinned
    }
    
    func loadLabel(_ item: Project) {
        let keyStore = NSUbiquitousKeyValueStore()
        let documents = readDirectory(item.url)

        let isFirst = true
        for document in documents {
            let url = document.0 as URL
            
            #if os(iOS)
                if
                    isFirst,
                    let currentNoteURL = EditTextView.note?.url,
                    currentNoteURL == url {
                    continue
                }
            
                if FileManager.default.isUbiquitousItem(at: url) {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                }
            #endif
            
            let note = Note(url: url)
            note.parseURL()
            
            if item.isArchive {
                note.loadTags()
            }
            
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
    
    public func unload(project: Project) {
        let notes = noteList.filter({ $0.project != nil && $0.project!.isArchive })
        for note in notes {
            if let i = noteList.index(of: note) {
                noteList.remove(at: i)
            }
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
    
    #if os(iOS)
    public func getBy(metaId: Int) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.metaId == metaId
                )
            })
    }
    #endif
    
    func getBy(name: String) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.name == name
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
            _ = add(project: childProject)
            
            return pURL
        }
        
        return nil
#else
        return UserDefaultsManagement.documentDirectory
#endif
    }
            
    var isActiveCaching = false
    var terminateBusyQueue = false
    
    func cacheMarkdown(project: Project? = nil) {
        guard !self.isActiveCaching else {
            self.terminateBusyQueue = true
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            self.isActiveCaching = true
            
            var markdownDocuments = [Note]()
            
            if let project = project {
                markdownDocuments = self.noteList.filter{
                    $0.isMarkdown() && $0.project == project
                }
            } else {
                markdownDocuments = self.noteList.filter{
                    $0.isMarkdown()
                }
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
    
    func removeNotes(notes: [Note], fsRemove: Bool = true, completion: @escaping ([URL: URL]?) -> ()) {
        guard notes.count > 0 else {
            completion(nil)
            return
        }
        
        for note in notes {
            #if os(OSX)
                for tag in note.tagNames {
                    _ = removeTag(tag)
                }
            #endif
            removeBy(note: note)
        }
        
        var removed = [URL: URL]()
        
        if fsRemove {
            for note in notes {
                if let trashURLs = note.removeFile() {
                    removed[trashURLs[0]] = trashURLs[1]
                }
            }
        }
        
        if removed.count > 0 {
            completion(removed)
        } else {
            completion(nil)
        }
    }
        
    func getSubFolders(url: URL) -> [NSURL]? {
        guard let fileEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions()) else { return nil }
        
        var subdirs = [NSURL]()
        
        var i = 0
        while let url = fileEnumerator.nextObject() as? NSURL {
            i = i + 1
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
            
            if i > 50000 {
                break
            }
        }
        
        return subdirs
    }
    
    public func getCurrentProject() -> Project? {
        return projects.first
    }
    
    public func getTags() -> [String] {
        return tagNames
    }
    
    public func addTag(_ string: String) {
        if !tagNames.contains(string) {
            tagNames.append(string)
        }
    }
    
    public func removeTag(_ string: String) -> Bool {
        if noteList.filter({ $0.tagNames.contains(string) && !$0.isTrash() }).count < 2 {
            if let i = tagNames.index(of: string) {
                tagNames.remove(at: i)
                return true
            }
        }
        
        return false
    }
    
    public func getAllTrash() -> [Note] {
        return
            noteList.filter {
                $0.isTrash()
            }
    }
    
    public func initiateCloudDriveSync() {
        for project in projects {
            self.syncDirectory(url: project.url)
        }
        
        for imageFolder in imageFolders {
            self.syncDirectory(url: imageFolder)
        }
    }
    
    public func syncDirectory(url: URL) {
        do {
            let directoryFiles =
                try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey])
            
            let images =
                directoryFiles.filter {
                    ["icloud"].contains($0.pathExtension.lowercased())}.map{
                        url in (
                            url,
                            (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                                )?.contentModificationDate ?? Date.distantPast,
                            (try? url.resourceValues(forKeys: [.creationDateKey])
                                )?.creationDate ?? Date.distantPast
                        )
            }
            
            for image in images {
                let url = image.0 as URL
                if FileManager.default.isUbiquitousItem(at: url) {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                }
            }
        } catch {
            print("Project not found, url: \(url)")
        }
    }
}
