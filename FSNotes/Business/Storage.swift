//
//  NotesCollection.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/9/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import CoreServices

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

class Storage {
    static var instance: Storage? = nil
    
    var noteList = [Note]()
    private var projects = [Project]()
    private var imageFolders = [URL]()
    public var tagNames = [String]()
    
    var notesDict: [String: Note] = [:]

    var allowedExtensions = [
        "md", "markdown",
        "txt",
        "rtf",
        "fountain",
        "textbundle",
        "etp" // Encrypted Text Pack
    ]

    var pinned: Int = 0
    
#if os(iOS)
    let initialFiles = [
        "FSNotes - Readme.md",
        "FSNotes - Code Highlighting.md"
    ]
#else
    let initialFiles = [
        "FSNotes - Readme.md",
        "FSNotes - Shortcuts.md",
        "FSNotes - Code Highlighting.md"
    ]
#endif
    
    private var bookmarks = [URL]()

    init() {
        #if os(OSX)
            let bookmark = SandboxBookmark.sharedInstance()
            bookmarks = bookmark.load()
        #endif
        
        guard let url = UserDefaultsManagement.storageUrl else { return }
        
        var name = url.lastPathComponent
        if let iCloudURL = getCloudDrive(), iCloudURL == url {
            name = "iCloud Drive"
        }

        let project = Project(url: url, label: name, isRoot: true, isDefault: true)
        _ = add(project: project)

        #if os(OSX)
        for url in bookmarks {
            if url.pathExtension == "css" {
                continue
            }

            guard !projectExist(url: url) else {
                continue
            }
            
            if url == UserDefaultsManagement.archiveDirectory {
                continue
            }
            
            let project = Project(url: url, label: url.lastPathComponent, isRoot: true)
            _ = add(project: project)
        }
        #endif

        let archiveLabel = NSLocalizedString("Archive", comment: "Sidebar label")

        if let archive = UserDefaultsManagement.archiveDirectory {
            let project = Project(url: archive, label: archiveLabel, isRoot: false, isDefault: false, isArchive: true)
            _ = add(project: project)
        }
    }

    public func makeTempEncryptionDirectory() -> URL? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Encryption")
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            return url
        } catch {
            return nil
        }
    }

    public func getChildProjects(project: Project) -> [Project] {
        return projects.filter({ $0.parent == project }).sorted(by: { $0.label.lowercased() < $1.label.lowercased() })
    }

    public func getRootProject() -> Project? {
        return projects.first(where: { $0.isRoot })
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
            
    func projectExist(url: URL) -> Bool {
        return projects.contains(where: {$0.url == url})
    }
    
    public func removeBy(project: Project) {
        let list = noteList.filter({ $0.project ==
            project })
        
        for note in list {
            if let i = noteList.firstIndex(where: {$0 === note}) {
                noteList.remove(at: i)
            }
        }
        
        if let i = projects.firstIndex(of: project) {
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
        #else
        if #available(iOS 11.0, *) {
            return try? FileManager.default.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: url, create: false)
        } else {
            return nil
        }
        #endif
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

    public func loadProjects(withTrash: Bool = true) {
        noteList.removeAll()

        for project in projects {
            if project.isTrash && !withTrash {
                continue
            }

            loadLabel(project)
        }
    }

    func loadDocuments(tryCount: Int = 0, completion: @escaping () -> Void) {
        loadProjects()
        
        _ = restoreCloudPins()

        let count = self.noteList.count
        var i = 0

        #if os(iOS)
        DispatchQueue.global().async {
            for note in self.noteList {
                note.load()
                i += 1
                if i == count {
                    print("Loaded notes: \(count)")
                    completion()
                }
            }
        }
        #endif

        self.noteList = self.sortNotes(noteList: self.noteList, filter: "")

        guard !checkFirstRun() else {
            if tryCount == 0 {
                loadDocuments(tryCount: 1) {}
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

    public func getMainProject() -> Project {
        return projects.first!
    }
    
    public func getProjects() -> [Project] {
        return projects
    }

    public func getProjectBy(element: Int) -> Project? {
        if projects.indices.contains(element) {
            return projects[element]
        }

        return nil
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
        
    func sortNotes(noteList: [Note], filter: String, project: Project? = nil, operation: BlockOperation? = nil) -> [Note] {
        var searchQuery = ""
        if filter.count > 0 {
            searchQuery = filter.lowercased()
        }

        return noteList.sorted(by: {
            if let operation = operation, operation.isCancelled {
                return false
            }
            
            if filter.count > 0 && $0.title.lowercased().starts(with: searchQuery) {
                if $0.title.lowercased().starts(with: searchQuery) && $1.title.lowercased().starts(with: searchQuery) {
                    return sortQuery(note: $0, next: $1, project: project)
                }
                
                return true
            }
            
            return sortQuery(note: $0, next: $1, project: project)
        })
    }
    
    private func sortQuery(note: Note, next: Note, project: Project?) -> Bool {
        let sortDirection = UserDefaultsManagement.sortDirection
        let sort = project?.sortBy ?? UserDefaultsManagement.sort

        if note.isPinned == next.isPinned {
            switch sort {
            case .creationDate:
                if let prevDate = note.creationDate, let nextDate = next.creationDate {
                    return sortDirection && prevDate > nextDate || !sortDirection && prevDate < nextDate
                }
            case .modificationDate:
                return sortDirection && note.modifiedLocalAt > next.modifiedLocalAt || !sortDirection && note.modifiedLocalAt < next.modifiedLocalAt
            case .title:
                return sortDirection && note.title.lowercased() < next.title.lowercased() || !sortDirection && note.title.lowercased() > next.title.lowercased()
            }
        }
        
        return note.isPinned && !next.isPinned
    }

    func loadLabel(_ item: Project, shouldScanCache: Bool = false) {
        let documents = readDirectory(item.url)

        for document in documents {
            let url = document.0 as URL

            #if os(OSX)
                if let currentNoteURL = EditTextView.note?.url,
                    currentNoteURL == url {
                    continue
                }
            #endif

            let note = Note(url: url, with: item)
            
            if item.isArchive {
                note.loadTags()
            }

            if (url.pathComponents.count == 0) {
                continue
            }
            
            note.modifiedLocalAt = document.1
            note.creationDate = document.2
            note.project = item
            
            #if CLOUDKIT
            #else
                if let data = try? note.url.extendedAttribute(forName: "co.fluder.fsnotes.pin") {
                    let isPinned = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
                        ptr.load(as: Bool.self)
                    }

                    note.isPinned = isPinned
                }
            #endif

            #if os(OSX)
                note.load()
            #endif

            if note.isPinned {
                pinned += 1
            }
            
            noteList.append(note)

            if shouldScanCache {
                note.markdownCache()
            }
        }
    }
    
    public func unload(project: Project) {
        let notes = noteList.filter({ $0.project.isArchive })
        for note in notes {
            if let i = noteList.firstIndex(where: {$0 === note}) {
                noteList.remove(at: i)
            }
        }
    }

    public func reLoadTrash() {
        let notes = noteList.filter({ $0.isTrash() })
        for note in notes {
            if let i = noteList.firstIndex(where: {$0 === note}) {
                noteList.remove(at: i)
            }
        }

        for project in projects {
            if project.isTrash {
                self.loadLabel(project)
            }
        }
    }

    public func readDirectory(_ url: URL) -> [(URL, Date, Date)] {
        do {
            let directoryFiles =
                try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .typeIdentifierKey], options:.skipsHiddenFiles)
            
            return
                directoryFiles.filter {
                    allowedExtensions.contains($0.pathExtension)
                    || self.isValidUTI(url: $0)
                }.map{
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

    public func isValidUTI(url: URL) -> Bool {
        guard url.fileSize < 100000000 else { return false }

        guard let typeIdentifier = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier else { return false }

        return UTTypeConformsTo(typeIdentifier as CFString, kUTTypeText)
    }
    
    func add(_ note: Note) {
        if !noteList.contains(where: { $0.name == note.name && $0.project == note.project }) {
           noteList.append(note)
        }
    }
    
    func removeBy(note: Note) {
        if let i = noteList.firstIndex(where: {$0 === note}) {
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
        if noteList.isEmpty {
            return nil
        }

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
                    $0.name == name
                )
            })
    }
    
    func getBy(title: String) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.title.lowercased() == title.lowercased()
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
        if let icloud = UserDefaultsManagement.iCloudDocumentsContainer {
            return icloud
        }

        return UserDefaultsManagement.storageUrl
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

            #if NOT_EXTENSION || os(OSX)
            for note in markdownDocuments {
                note.markdownCache()

                guard let currentNote = EditTextView.note else {
                    continue
                }

                if note.url == currentNote.url {
                #if os(OSX)
                    ViewController.shared()?.refillEditArea()
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
                    self.loadDocuments() {}
                    break
                }
            }
            #endif
            
            self.isActiveCaching = false
        }
    }
    
    func removeNotes(notes: [Note], fsRemove: Bool = true, completion: @escaping ([URL: URL]?) -> ()) {
        guard notes.count > 0 else {
            completion(nil)
            return
        }
        
        for note in notes {
            note.removeCacheForPreviewImages()
            
            #if os(OSX)
                for tag in note.tagNames {
                    _ = removeTag(tag)
                }
            #else
                removeBy(note: note)
            #endif
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

        var extensions = self.allowedExtensions
        for ext in ["jpg", "png", "gif", "jpeg", "json", "JPG", "PNG", ".icloud"] {
            extensions.append(ext)
        }
        let lastPatch = ["assets", ".cache", "i", ".Trash"]

        let urls = fileEnumerator.allObjects.filter { !extensions.contains(($0 as? NSURL)!.pathExtension!) && !lastPatch.contains(($0 as? NSURL)!.lastPathComponent!) } as! [NSURL]
        var subdirs = [NSURL]()
        var i = 0

        for url in urls {
            i = i + 1

            do {
                var isDirectoryResourceValue: AnyObject?
                try url.getResourceValue(&isDirectoryResourceValue, forKey: URLResourceKey.isDirectoryKey)

                var isPackageResourceValue: AnyObject?
                try url.getResourceValue(&isPackageResourceValue, forKey: URLResourceKey.isPackageKey)

                if isDirectoryResourceValue as? Bool == true,
                    isPackageResourceValue as? Bool == false {
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
        return tagNames.sorted { $0 < $1 }
    }
    
    public func hasTags() -> Bool {
        return !self.tagNames.isEmpty
    }
    
    public func addTag(_ string: String) {
        if !tagNames.contains(string) {
            tagNames.append(string)
        }
    }
    
    public func removeTag(_ string: String) -> Bool {
        if noteList.filter({ $0.tagNames.contains(string) && !$0.isTrash() }).count < 2 {
            if let i = tagNames.firstIndex(of: string) {
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

    #if os(iOS)
    public func createProject(name: String) -> Project {
        let storageURL = UserDefaultsManagement.storageUrl!

        var url = storageURL.appendingPathComponent(name)

        if FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
            url = storageURL.appendingPathComponent("\(name) \(String(Date().toMillis()))")
        }

        let project = Project(url: url)
        project.createDirectory()

        _ = add(project: project)
        return project
    }
    #endif

    public func initNote(url: URL) -> Note? {
        guard let project = self.getProjectBy(url: url) else { return nil }

        let note = Note(url: url, with: project)

        return note
    }

    private func cleanTrash() {
        if #available(iOS 11.0, *) {
            guard let trash = try? FileManager.default.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: UserDefaultsManagement.storageUrl, create: false) else { return }

            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil, options: [])

                for fileURL in fileURLs {
                    try FileManager.default.removeItem(at: fileURL)
                }
            } catch  { print(error) }
        }
    }

    public func fullCacheReset() {
        for note in noteList {
            note.isCached = false
        }
    }

    public func saveCloudPins() {
        #if CLOUDKIT || os(iOS)
        if let pinned = getPinned() {
            var names = [String]()
            for note in pinned {
                names.append(note.name)
            }

            let keyStore = NSUbiquitousKeyValueStore()
            keyStore.set(names, forKey: "co.fluder.fsnotes.pins.shared")
            keyStore.synchronize()

            print("Pins successfully saved: \(names)")
        }
        #endif
    }

    public func restoreCloudPins() -> (removed: [Note]?, added: [Note]?) {
        var added = [Note]()
        var removed = [Note]()

        #if CLOUDKIT || os(iOS)
        let keyStore = NSUbiquitousKeyValueStore()
        keyStore.synchronize()
        
        if let names = keyStore.array(forKey: "co.fluder.fsnotes.pins.shared") as? [String] {
            if let pinned = getPinned() {
                for note in pinned {
                    if !names.contains(note.name) {
                        note.removePin(cloudSave: false)
                        removed.append(note)
                    }
                }
            }

            for name in names {
                if let note = getBy(name: name) {
                    note.addPin(cloudSave: false)
                    added.append(note)
                }
            }
        }
        #endif

        return (removed, added)
    }

    public func getPinned() -> [Note]? {
        return noteList.filter({ $0.isPinned })
    }

    public func remove(project: Project) {
        if let index = projects.firstIndex(of: project) {
            projects.remove(at: index)
        }
    }
}
