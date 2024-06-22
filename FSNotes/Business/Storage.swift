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
    public static var instance: Storage? = nil
    
    public var noteList = [Note]()
    public var projects = [Project]()
    private var imageFolders = [URL]()
    public var tags = [String]()

    var notesDict: [String: Note] = [:]

    public var allowedExtensions = [
        "md",
        "markdown",
        "txt",
        "rtf",
        "fountain",
        "textbundle",
        "etp" // Encrypted Text Pack
    ]

    public var shouldMovePrompt = false

    private var trashURL = URL(string: String())
    private var archiveURL = URL(string: String())

    private let lastNewsDate = "2023-05-25"
    public var isCrashedLastTime = false

    private var relativeInlineImagePaths = [String]()

    public var plainWriter = OperationQueue.init()
    public var ciphertextWriter = OperationQueue.init()
    
    init() {
        
        // Load root
        
        print("A. Bookmarks loading is started")
        let bookmarksManager = SandboxBookmark.sharedInstance()
        bookmarksManager.load()
        
        let storageType = UserDefaultsManagement.storageType
        guard let url = getRoot() else { return }
        
        removeCachesIfCrashed()

    #if os(OSX)
        if storageType == .local && UserDefaultsManagement.storageType == .iCloudDrive {
            shouldMovePrompt = true
        }
    #endif

        let name = getDefaultName(url: url)
        let project =
            Project(
                storage: self,
                url: url,
                label: name,
                isDefault: true
            )
        
        insertProject(project: project)
        
        assignTrash(by: project.url)
        assignBookmarks()
                
    #if os(OSX)
        loadCachedProjects()
        loadProjectRelations()
    #endif

        checkWelcome()
        loadNotesCloudPins()

        plainWriter.maxConcurrentOperationCount = 1
        plainWriter.qualityOfService = .userInteractive

        ciphertextWriter.maxConcurrentOperationCount = 1
        ciphertextWriter.qualityOfService = .userInteractive
        
    #if os(iOS)
        let revHistory = getRevisionsHistory()
        let revHistoryDS = getRevisionsHistoryDocumentsSupport()

        if FileManager.default.directoryExists(atUrl: revHistory) {
            try? FileManager.default.moveItem(at: revHistory, to: revHistoryDS)
        }

        if !FileManager.default.directoryExists(atUrl: revHistoryDS) {
            try? FileManager.default.createDirectory(at: revHistoryDS, withIntermediateDirectories: true, attributes: nil)
        }
    #endif
    }
    
    public func insertProject(project: Project) {
        if projectExist(url: project.url) {
            return
        }
        
        projects.append(project)
    }
    
    public static func shared() -> Storage {
        guard let storage = self.instance else {
            self.instance = Storage()
            return self.instance!
        }
        return storage
    }
    
    private func getDefaultName(url: URL) -> String {
        var name = url.lastPathComponent
        if let iCloudURL = getCloudDrive(), iCloudURL == url {
            name = "iCloud Drive"
        }
        return name
    }

    public func loadCachedProjects() {
        
        // Inbox
        getDefault()?.loadNotes()
        
        // Trash
        getDefaultTrash()?.loadNotes()
        
        loadBookmarkNotes()

        if let urls = getCachedTree() {
            for url in urls {
                _ = insert(url: url)
            }
        }
    }

    public func loadBookmarkNotes() {

        // Root boookmarks
        for project in projects {
            if project.isBookmark {
                project.loadNotes()
            }
        }
    }

    public func getRoot() -> URL? {
        #if targetEnvironment(simulator) || os(OSX)
            return UserDefaultsManagement.storageUrl
        #endif

        if !UserDefaultsManagement.iCloudDrive {
            return getLocalDocuments()
        }
        
        guard let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .standardized
        else { return getLocalDocuments() }

        if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
            do {
                try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)

                return iCloudDocumentsURL.standardized
            } catch {
                print("Home directory creation: \(error)")
            }
            return nil
        } else {
            return iCloudDocumentsURL.standardized
        }
    }

    public func getLocalDocuments() -> URL? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.standardized

        return url
    }

    // removes all caches after crash

    private func removeCachesIfCrashed() {
        if UserDefaultsManagement.crashedLastTime {
            
            removeCachedTree()
            
            if let cache = getCacheDir() {
                if let files = try? FileManager.default.contentsOfDirectory(atPath: cache.path) {
                    for file in files {
                        let url = cache.appendingPathComponent(file)
                        try? FileManager.default.removeItem(at: url)
                    }
                }
            }
        }

        isCrashedLastTime = UserDefaultsManagement.crashedLastTime

        UserDefaultsManagement.crashedLastTime = true
    }

    public func getCacheDir() -> URL? {
        guard let cacheDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first, let url = URL(string: "file://" + cacheDir)
        else { return nil }

        return url
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
    
    public func getDefault() -> Project? {
        return projects.first(where: { $0.isDefault })
    }
    
    public func getSidebarProjects() -> [Project] {
        return projects
            .filter({ $0.isBookmark || $0.parent?.isDefault == true })
            .sorted(by: { $0.label.lowercased() < $1.label.lowercased() })
            .sorted(by: { $0.settings.priority < $1.settings.priority })
    }

    public func getDefaultTrash() -> Project? {
        return projects.first(where: { $0.isTrash })
    }
        
    public func insert(url: URL, bookmark: Bool = false) -> [Project]? {
        if projectExist(url: url)
            || url.lastPathComponent == "i"
            || url.lastPathComponent == "files"
            || url.lastPathComponent == "assets"
            || url.lastPathComponent == ".icloud"
            || url.path.contains(".git")
            || url.path.contains(".revisions")
            || url.path.contains(".Trash")
            || url.path.contains(".cache")
            || url.path.contains("Trash")
            || url.path.contains("/.")
            || url.path.contains(".textbundle") {
            
            return nil
        }
        
        let project = Project(storage: self, url: url, isBookmark: bookmark)
        var insert = [project]
        
        let results = project.getProjectsFSAndMemoryDiff()
        insert.append(contentsOf: results.1)
                
        for item in insert {
            if !projectExist(url: item.url) {
                insertProject(project: item)
                
                item.loadNotes()
            }
        }
        
        return insert
    }

    private func assignTrash(by url: URL) {
        var trashURL = url.appendingPathComponent("Trash", isDirectory: true)
        
    #if os(OSX)
        if let trash = UserDefaultsManagement.trashURL {
            trashURL = trash
        }
    #endif
        
        do {
            try FileManager.default.contentsOfDirectory(atPath: trashURL.path)
        } catch {
            var isDir = ObjCBool(false)
            if !FileManager.default.fileExists(atPath: trashURL.path, isDirectory: &isDir) && !isDir.boolValue {
                do {
                    try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: false, attributes: nil)

                    print("New trash created: \(trashURL)")
                } catch {
                    print("Trash dir error: \(error)")
                }
            }
        }

        guard !projectExist(url: trashURL) else { return }

        let project = Project(storage: self, url: trashURL, isTrash: true)
        insertProject(project: project)

        self.trashURL = trashURL
    }
    
    private func getCloudDrive() -> URL? {
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents").standardized {
            
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
        self.noteList.removeAll(where: { $0.project ==
            project })
        
        projects.removeAll(where: { $0.url == project.url })
    }

    public func loadNotesContent() {
        for note in noteList {
            note.load()
        }
    }

    public func assignBookmarks() {
        let bookmarksManager = SandboxBookmark.sharedInstance()
        let bookmarks = bookmarksManager.getRestoredUrls()
        
        for url in bookmarks {
            if url.pathExtension == "css" 
                || projectExist(url: url)
                || UserDefaultsManagement.gitStorage == url {
                continue
            }
            

            let project = Project(storage: self, url: url, isBookmark: true)
            insertProject(project: project)
        }
    }
    
    func getTrash(url: URL) -> URL? {
        return try? FileManager.default.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: url, create: false)
    }
    
    public func resetCacheAttributes() {
        for note in self.noteList {
            note.cacheHash = nil
        }
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

    public func findAllProjectsExceptDefault() -> [Project] {
        return projects.filter({ !$0.isDefault  })
    }

    public func getNonSystemProjects() -> [Project] {
        return projects.filter({
            !$0.isDefault
            && !$0.isTrash
        })
    }

    public func getAvailableProjects() -> [Project] {
        return projects.filter({
            !$0.isDefault
            && !$0.isTrash
            && $0.settings.showInSidebar
        })
    }
        
    public func getProjectPaths() -> [String] {
        var pathList: [String] = []
        let projects = getProjects()
        
        for project in projects {
            pathList.append(NSString(string: project.url.path).expandingTildeInPath)
        }
        
        return pathList
    }
    
    public func getProjectByNote(url: URL) -> Project? {
        let projectURL = url.deletingLastPathComponent()
        
        return
            projects.first(where: {
                return (
                    $0.url == projectURL
                )
            })
    }

    public func getProjectBy(url: URL) -> Project? {
        return
            projects.first(where: {
                return (
                    $0.url == url
                )
            })
    }
        
    func sortNotes(noteList: [Note], filter: String? = nil, project: Project? = nil, operation: BlockOperation? = nil) -> [Note] {
        var noteList = noteList
        
        // Pre sort by creation and modified date, title
        if let filter = filter, filter.count > 0 {
            noteList = noteList.sorted(by: {
                if let operation = operation, operation.isCancelled {
                    return false
                }
                
                return sortQuery(note: $0, next: $1, project: project)
            })
        }
        
        return noteList.sorted(by: {
            if let operation = operation, operation.isCancelled {
                return false
            }

            if let filter = filter, filter.count > 0 {
                if ($0.title == filter && $1.title != filter) {
                    return true
                }

                if ($0.fileName == filter && $1.fileName != filter) {
                    return true
                }

                if (
                    $0.title.startsWith(string: filter)
                        || $0.fileName.startsWith(string: filter)
                ) && (
                    !$1.title.startsWith(string: filter)
                        && !$1.fileName.startsWith(string: filter)
                ) {
                    return true
                }
                
                return false
            }
            
            return sortQuery(note: $0, next: $1, project: project)
        })
    }
    
    private func sortQuery(note: Note, next: Note, project: Project?) -> Bool {
        var sortDirection: SortDirection
        var sort: SortBy

        if let project = project, project.settings.sortBy != .none {
            sortDirection = project.settings.sortDirection
        } else {
            sortDirection = UserDefaultsManagement.sortDirection ? .desc : .asc
        }
        
        if let sortBy = project?.settings.sortBy, sortBy != .none {
            sort = sortBy
        } else {
            sort = UserDefaultsManagement.sort
        }

        if note.isPinned == next.isPinned {
            switch sort {
            case .creationDate:
                if let prevDate = note.creationDate, let nextDate = next.creationDate {
                    return sortDirection == .asc && prevDate < nextDate || sortDirection == .desc && prevDate > nextDate
                }
            case .modificationDate, .none:
                return sortDirection == .asc && note.modifiedLocalAt < next.modifiedLocalAt || sortDirection == .desc && note.modifiedLocalAt > next.modifiedLocalAt
            case .title:
                var title = note.title.lowercased()
                var nextTitle = next.title.lowercased()

                if note.isEncryptedAndLocked() {
                    title = note.fileName.lowercased()
                }

                if next.isEncryptedAndLocked() {
                    nextTitle = next.fileName.lowercased()
                }

                return
                    sortDirection == .asc && title < nextTitle ||
                    sortDirection == .desc && title > nextTitle
            }
        }
        
        return note.isPinned && !next.isPinned
    }

    public func isValidNote(url: URL) -> Bool {
        if allowedExtensions.contains(url.pathExtension) || isValidUTI(url: url) {
            
            // disallow parent dir with dot at start – https://github.com/glushchenko/fsnotes/issues/1653
            let qty = url.pathComponents.count
            if qty > 1 {
                return !url.pathComponents[qty-2].startsWith(string: ".")
            }
            
            return true
        }
        
        return false
    }
    
    public func isValidUTI(url: URL) -> Bool {
        guard url.fileSize < 100000000 else { return false }

        guard let typeIdentifier = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier else { return false }

        let type = typeIdentifier as CFString
        if type == kUTTypeFolder {
            return false
        }

        return UTTypeConformsTo(type, kUTTypeText)
    }
    
    func add(_ note: Note) {
        if !noteList.contains(where: { $0.name == note.name && $0.project == note.project }) {
           noteList.append(note)
        }
    }

    public func contains(note: Note) -> Bool {
        if noteList.contains(where: { $0.name == note.name && $0.project == note.project }) {
           return true
        }

        return false
    }
    
    func removeBy(note: Note) {
        if let i = noteList.firstIndex(where: {$0 === note}) {
            noteList.remove(at: i)
        }
    }
    
    func getNextId() -> Int {
        return noteList.count
    }
    
    func getBy(url: URL, caseSensitive: Bool = false) -> Note? {
        let standardized = url.standardized

        if caseSensitive {
            return
                noteList.first(where: {
                    return (
                        $0.url.path == standardized.path
                    )
                })
        }

        return
            noteList.first(where: {
                return (
                    $0.url.path.lowercased() == standardized.path.lowercased()
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
    
    func getBy(title: String, exclude: Note? = nil) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.title.lowercased() == title.lowercased()
                    && !$0.isTrash()
                    && (exclude == nil || $0 != exclude)
                )
            })
    }

    func getBy(fileName: String, exclude: Note? = nil) -> Note? {
        return
            noteList.first(where: {
                return (
                    $0.fileName.lowercased() == fileName.lowercased()
                        && !$0.isTrash()
                        && (exclude == nil || $0 != exclude)
                )
            })
    }
    
    func getBy(startWith: String) -> [Note]? {
        return
            noteList.filter{
                $0.title.lowercased().starts(with: startWith.lowercased())
            }
    }

    func getByUrl(endsWith: String) -> Note? {
        for note in noteList {
            if note.url.path.hasSuffix(endsWith) {
                return note
            }
        }

        return nil
    }

    func getBy(contains: String) -> [Note]? {
        return
            noteList.filter{
                $0.title.lowercased().contains(contains.lowercased())
            }
    }

    public func getTitles(by word: String? = nil) -> [String]? {
        var notes = noteList

        if let word = word {
            notes = notes
                .filter{
                    $0.title.contains(word) && $0.project.settings.isFirstLineAsTitle()
                    || $0.fileName.contains(word) && !$0.project.settings.isFirstLineAsTitle()

                }
                .filter({ !$0.isTrash() })

            guard notes.count > 0 else { return nil }

            var titles = notes.map{ String($0.project.settings.isFirstLineAsTitle() ? $0.title : $0.fileName) }

            titles = Array(Set(titles))
            titles = titles
                .filter({ !$0.starts(with: "![](") && !$0.starts(with: "[[") })
                .sorted { (first, second) -> Bool in
                    if first.starts(with: word) && second.starts(with: word)
                        || !first.starts(with: word) && !second.starts(with: word)
                    {
                        return first < second
                    }

                    return (first.starts(with: word) && !second.starts(with: word))
                }

            if titles.count > 100 {
                return Array(titles[0..<100])
            }

            return titles
        }

        guard notes.count > 0 else { return nil }

        notes = notes.sorted { (first, second) -> Bool in
            return first.modifiedLocalAt > second.modifiedLocalAt
        }

        let titles = notes
            .filter({ !$0.isTrash() })
            .map{ String($0.project.settings.isFirstLineAsTitle() ? $0.title : $0.fileName ) }
            .filter({ $0.count > 0 })
            .filter({ !$0.starts(with: "![](") })
            .prefix(100)

        return Array(titles)
    }
    
    func getDemoSubdirURL() -> URL? {
#if os(OSX)
        if let project = projects.first {
            return project.url
        }
        
        return nil
#else
        if let icloud = UserDefaultsManagement.iCloudDocumentsContainer {
            return icloud
        }

        return UserDefaultsManagement.storageUrl
#endif
    }
    
    func removeNotes(notes: [Note], fsRemove: Bool = true, completely: Bool = false, completion: @escaping ([URL: URL]?) -> ()) {
        guard notes.count > 0 else {
            completion(nil)
            return
        }
        
        for note in notes {
            note.removeCacheForPreviewImages()
            removeBy(note: note)
        }
        
        var removed = [URL: URL]()
        
        if fsRemove {
            for note in notes {
                if let trashURLs = note.removeFile(completely: completely) {
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

    private func fetchAllDirectories(url: URL) -> [URL]? {
        guard let fileEnumerator =
            FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: nil,
                options: FileManager.DirectoryEnumerationOptions()
            )
        else { return nil }

        var extensions = self.allowedExtensions
        extensions.append(contentsOf: [
            "jpg", "png", "gif", "jpeg", "json", "JPG",
            "PNG", ".icloud", ".cache", ".Trash", "i"
        ])

        let urls = fileEnumerator.allObjects.compactMap({ $0 as? URL })
            .filter({
                !extensions.contains($0.pathExtension)
                && !extensions.contains($0.lastPathComponent)
                && !$0.path.contains("/assets")
                && !$0.path.contains("/.cache")
                && !$0.path.contains("/files")
                && !$0.path.contains("/.Trash")
                && !$0.path.contains("/Trash")
                && !$0.path.contains(".textbundle")
                && !$0.path.contains(".revisions")
                && !$0.path.contains("/.git")
            })

        var fin = [URL]()
        var i = 0

        for url in urls {
            do {
                var isDirectoryResourceValue: AnyObject?
                try (url as NSURL).getResourceValue(&isDirectoryResourceValue, forKey: URLResourceKey.isDirectoryKey)

                var isPackageResourceValue: AnyObject?
                try (url as NSURL).getResourceValue(&isPackageResourceValue, forKey: URLResourceKey.isPackageKey)

                if isDirectoryResourceValue as? Bool == true,
                    isPackageResourceValue as? Bool == false {
                    
                    i = i + 1
                    fin.append(url)
                }
            }
            catch let error as NSError {
                print("Error: ", error.localizedDescription)
            }

            if i > 200 {
                break
            }
        }

        return fin
    }
    
    public func getCurrentProject() -> Project? {
        return projects.first
    }

    public func getAllTrash() -> [Note] {
        return
            noteList.filter {
                $0.isTrash()
            }
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

    public func saveCloudPins() {
        #if CLOUD_RELATED_BLOCK
        if let pinned = getPinned() {
            var names = [String]()
            for note in pinned {
                names.append(note.getRelatedPath())
            }

            let keyStore = NSUbiquitousKeyValueStore()
            keyStore.set(names, forKey: "co.fluder.fsnotes.pins.shared")
            keyStore.synchronize()
        
            print("Pins successfully saved: \(names)")
        }
        #endif
    }

    public func loadPins(notes: [Note]) {
        #if CLOUD_RELATED_BLOCK
        let keyStore = NSUbiquitousKeyValueStore()
        keyStore.synchronize()

        var success = [Note]()

        guard let names = keyStore.array(forKey: "co.fluder.fsnotes.pins.shared") as? [String]
            else { return }

        for note in notes {
            if names.contains(note.getRelatedPath()) {
                note.addPin(cloudSave: false)
                success.append(note)
            }
        }
        
        #endif
    }

    public func restoreCloudPins() -> (removed: [Note]?, added: [Note]?) {
        var added = [Note]()
        var removed = [Note]()

        #if CLOUD_RELATED_BLOCK
        let keyStore = NSUbiquitousKeyValueStore()
        keyStore.synchronize()
        
        if let names = keyStore.array(forKey: "co.fluder.fsnotes.pins.shared") as? [String] {
            if let pinned = getPinned() {
                for note in pinned {
                    if !names.contains(note.getRelatedPath()) {
                        note.removePin(cloudSave: false)
                        removed.append(note)
                    }
                }
            }

            for name in names {
                if let note = getByUrl(endsWith: name), !note.isPinned {
                    note.addPin(cloudSave: false)
                    added.append(note)
                }
            }
        }
        #endif

        return (removed, added)
    }
    
    public func getUpdatedPins() -> [Note] {
        var notes = [Note]()

        #if CLOUD_RELATED_BLOCK
        let keyStore = NSUbiquitousKeyValueStore()
        keyStore.synchronize()
        
        if let names = keyStore.array(forKey: "co.fluder.fsnotes.pins.shared") as? [String] {
            if let pinned = getPinned() {
                for note in pinned {
                    if !names.contains(note.getRelatedPath()) {
                        notes.append(note)
                    }
                }
            }

            for name in names {
                if let note = getByUrl(endsWith: name), !note.isPinned {
                    notes.append(note)
                }
            }
        }
        #endif

        return notes
    }
    
    public func loadNotesCloudPins() {
        _ = restoreCloudPins()
    }

    public func getPinned() -> [Note]? {
        return noteList.filter({ $0.isPinned })
    }

    public func remove(project: Project) {
        if let index = projects.firstIndex(of: project) {
            projects.remove(at: index)
            
            cleanCachedTree(url: project.url)
        }
        
        removeBy(project: project)
    }

    public func getNotesBy(project: Project) -> [Note] {
        return noteList.filter({ $0.project == project })
    }

    public func loadProjects(from urls: [URL]) {
        var result = [URL]()
        for url in urls {
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
                result.append(url)
            } catch {
                print(error)
            }
        }

        let projects =
            result.compactMap({ Project(storage: self, url: $0)})

        guard projects.count > 0 else {
            return
        }

        self.projects.removeAll()

        for project in projects {
            if project == projects.first {
                project.isDefault = true
                project.label = NSLocalizedString("Inbox", comment: "") 
            }

            insertProject(project: project)
        }
    }

    public func trashItem(url: URL) -> URL? {
        guard let trashURL = Storage.shared().getDefaultTrash()?.url else { return nil }

        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        var destination = trashURL.appendingPathComponent(url.lastPathComponent)

        var i = 0

        while FileManager.default.fileExists(atPath: destination.path) {
            let nextName = "\(fileName)_\(i).\(fileExtension)"
            destination = trashURL.appendingPathComponent(nextName)
            i += 1
        }

        return destination
    }

    public func getCache(key: String) -> Data? {
        guard let cacheDir =
            NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else { return nil }

        guard let url = URL(string: "file://" + cacheDir) else { return nil }

        let cacheURL = url.appendingPathComponent(key + ".cache")
        
        return try? Data(contentsOf: cacheURL)
    }

    public func saveProjectsCache() {
        for project in projects {
            project.saveCache()
        }
        
        saveCachedTree()
    }

    private func checkWelcome() {
        #if os(OSX)
            guard let storageUrl = getDefault()?.url else { return }
            guard UserDefaultsManagement.copyWelcome else { return }
            guard let bundlePath = Bundle.main.path(forResource: "Welcome", ofType: ".bundle") else { return }

            let bundle = URL(fileURLWithPath: bundlePath)
            let url = storageUrl.appendingPathComponent("Welcome")

            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: bundle.path)
                for file in files {
                    try? FileManager.default.copyItem(atPath: "\(bundle.path)/\(file)", toPath: "\(url.path)/\(file)")
                }
            } catch {
                print("Initial copy error: \(error)")
            }
        #else
            guard UserDefaultsManagement.copyWelcome else { return }
            guard noteList.isEmpty else { return }

            let welcomeFileName = "Meet FSNotes 6.textbundle"

            guard let src = Bundle.main.resourceURL?.appendingPathComponent("Initial/\(welcomeFileName)") else { return }

            guard let dst = getDefault()?.url.appendingPathComponent(welcomeFileName) else { return }

            do {
                if !FileManager.default.fileExists(atPath: dst.path) {
                    try FileManager.default.copyItem(atPath: src.path, toPath: dst.path)
                }
            } catch {
                print("Initial copy error: \(error)")
            }

            UserDefaultsManagement.copyWelcome = false
        #endif
    }

    public func getWelcome() -> URL? {
        let welcomeFileName = "FSNotes 4.0 for iOS.textbundle"

        guard let src = Bundle.main.resourceURL?.appendingPathComponent("Initial/\(welcomeFileName)") else { return nil }

        return src
    }

    public func getNewsDate() -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: lastNewsDate) {
            return date
        }
        return nil
    }

    public func isReadedNewsOutdated() -> Bool {
        guard let date = UserDefaultsManagement.lastNews, let newsDate = getNewsDate() else {
            return true
        }

        if newsDate > date {
            return true
        }

        return false
    }

    public func getNews() -> URL? {
        let file = "Meet FSNotes 6.textbundle"

        guard let src = Bundle.main.resourceURL?.appendingPathComponent("Initial/\(file)") else { return nil }

        return src
    }

    public func fetchNonSystemProjectURLs() -> [URL] {
        guard let main = getDefault() else { return [URL]() }
        
        var projectURLs = [URL]()

        if let main = getDefault() {
            projectURLs = getAllSubUrls(for: main.url)
        }

        let bookmarksManager = SandboxBookmark.sharedInstance()
        let urls = bookmarksManager.getRestoredUrls()

        for url in urls {
            if !projectURLs.contains(url)
                && url != main.url
                && url != trashURL {

                projectURLs.append(url)
                
                if let subUrls = fetchAllDirectories(url: url) {
                    for sUrl in subUrls {
                        if !projectURLs.contains(sUrl) {
                            projectURLs.append(sUrl)
                        }
                    }
                }
            }
        }

        return projectURLs
    }
    
    private func getAllSubUrls(for rootUrl: URL) -> [URL] {
        let trash = trashURL
        
        var projectURLs = [URL]()
        if let urls = fetchAllDirectories(url: rootUrl) {
            for url in urls {
                let standardizedURL = (url as URL).standardized
                if standardizedURL == trash
                    || standardizedURL == rootUrl {
                    continue
                }
                projectURLs.append(standardizedURL)
            }
        }
        
        return projectURLs
    }
    
    public func getProjectDiffs() -> ([Project], [Project]) {
        var insert = [Project]()
        var remove = [Project]()
        
        if let defaultProject = getDefault() {
            let defaultResults = defaultProject.getProjectsFSAndMemoryDiff()
            remove.append(contentsOf: defaultResults.0)
            insert.append(contentsOf: defaultResults.1)
        }
        
        let externalProjects = projects.filter({ $0.isBookmark })
        for project in externalProjects {
            let results = project.getProjectsFSAndMemoryDiff()
            remove.append(contentsOf: results.0)
            insert.append(contentsOf: results.1)
        }
        
        for insertItem in insert {
            insertProject(project: insertItem)
        }
        
        loadProjectRelations()
        saveCachedTree()
        
        for insertItem in insert {
            insertItem.loadNotes()
        }

        return (remove, insert)
    }

    public func importNote(url: URL) -> Note? {
        guard getBy(url: url) == nil, 
            let project = self.getProjectByNote(url: url)
        else { return nil }
        
        let note = Note(url: url, with: project)
        
        if note.isTextBundle() && !note.isFullLoadedTextBundle() {
            return nil
        }
        
        note.load()
        note.loadPreviewInfo()
        
        note.loadModifiedLocalAt()
        note.loadCreationDate()
        
        loadPins(notes: [note])
        add(note)
        
        print("FSWatcher import note: \"\(note.name)\"")
        
        return note
    }

    public func hideImages(directory: String, srcPath: String) {
        if !relativeInlineImagePaths.contains(directory) {
            let url = URL(fileURLWithPath: directory, isDirectory: true)

            relativeInlineImagePaths.append(directory)

            if !url.isHidden(),
               FileManager.default.directoryExists(atUrl: url),
               srcPath.contains("/"),
               !srcPath.contains("..")
            {
                if let contentList = try? FileManager.default.contentsOfDirectory(atPath: url.path), containsTextFiles(contentList) {
                    return
                }

                if let data = "true".data(using: .utf8) {
                    try? url.setExtendedAttribute(data: data, forName: "es.fsnot.hidden.dir")
                }
            }
        }
    }

    private func containsTextFiles(_ list: [String]) -> Bool {
        for item in list {
            let ext = (item as NSString).pathExtension.lowercased()
            if allowedExtensions.contains(ext) {
                return true
            }
        }

        return false
    }

    public func findParent(url: URL) -> Project? {
        let parentURL = url.deletingLastPathComponent()

        if let foundParent = projects.first(where: { $0.url == parentURL}) {
            return foundParent
        }

        return nil
    }

    #if os(OSX)
    public func saveProjectsExpandState() {
        var urls = [URL]()
        for project in projects {
            if project.isExpanded {
                urls.append(project.url)
            }
        }

        if var documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentDir.appendPathComponent("projects.state")

            if let data = try? NSKeyedArchiver.archivedData(withRootObject: urls, requiringSecureCoding: true) {
                try? data.write(to: documentDir)
            }
        }
    }

    public func restoreProjectsExpandState() {
        guard var documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        documentDir.appendPathComponent("projects.state")

        guard let data = FileManager.default.contents(atPath: documentDir.path) else {
            return
        }

        guard let urls = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL] else {
            return
        }

        for project in projects {
            if urls.contains(project.url) {
                project.isExpanded = true
            }
        }
    }
    #endif

    public func getRevisionsHistory() -> URL {
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let revisionsUrl = documentDir.appendingPathComponent(".revisions")

        return revisionsUrl
    }

    public func getRevisionsHistoryDocumentsSupport() -> URL {
        let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let revisionsUrl = documentDir.appendingPathComponent(".revisions")

        return revisionsUrl
    }
    
    public func saveUploadPaths() {
        let notes = noteList.filter({ $0.uploadPath != nil })
        
        var bookmarks = [URL: String]()
        for note in notes {
            if let path = note.uploadPath, path.count > 1 {
                bookmarks[note.url] = path
            }
        }
        
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: bookmarks, requiringSecureCoding: true) {
            UserDefaultsManagement.sftpUploadBookmarksData = data
        }
    }
    
    public func restoreUploadPaths() {
        guard let data = UserDefaultsManagement.sftpUploadBookmarksData,
              let uploadBookmarks = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSURL.self, NSString.self], from: data) as? [URL: String] else { return }

        for bookmark in uploadBookmarks {
            if let note = getBy(url: bookmark.key) {
                note.uploadPath = bookmark.value
            }
        }
    }
    
    public func saveAPIIds() {
        let notes = noteList.filter({ $0.apiId != nil })
        
        var bookmarks = [URL: String]()
        for note in notes {
            if let path = note.apiId, path.count > 1 {
                bookmarks[note.url] = path
            }
        }
        
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: bookmarks, requiringSecureCoding: true) {
            UserDefaultsManagement.apiBookmarksData = data
        }
    }
    
    public func restoreAPIIds() {
        guard let data = UserDefaultsManagement.apiBookmarksData,
              let uploadBookmarks = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSURL.self, NSString.self], from: data) as? [URL: String] else { return }

        for bookmark in uploadBookmarks {
            if let note = getBy(url: bookmark.key) {
                note.apiId = bookmark.value
            }
        }
    }
    
    public func saveNotesSettings() {
        var result = [URL: Bool]()

        for note in noteList {
            result[note.url] = note.previewState
        }
        
        if result.count > 0 {
            let projectsData = try? NSKeyedArchiver.archivedData(withRootObject: result, requiringSecureCoding: true)

            if let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? projectsData?.write(to: documentDir.appendingPathComponent("notes.settings"))
            }
        }
    }
    
    public func loadNotesSettings() {
        guard let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
 
        let projectsDataUrl = documentDir.appendingPathComponent("notes.settings")
        guard let data = try? Data(contentsOf: projectsDataUrl) else { return }
        
        guard let unarchivedData = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSURL.self, NSNumber.self], from: data) as? [URL: Bool] else { return }

        for note in noteList {
            let state = unarchivedData[note.url]
            note.previewState = state == true
        }
    }
        
    public func getGitKeysDir() -> URL? {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Keys", isDirectory: true) else { return nil }
        
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        return url
    }
    
    public func getProjectBy(settingsKey: String) -> Project? {
        return
            projects.first(where: {
                return (
                    $0.settingsKey == settingsKey
                )
            })
    }

    public func hasOrigins() -> Bool {
        return projects.first(where: {
            return (
                $0.settings.gitOrigin != nil && $0.settings.gitOrigin!.count > 0
            )
        }) != nil
    }

    public func getGitProjects() -> [Project]? {
        return projects.filter({
            return (
                $0.settings.gitOrigin != nil && $0.settings.gitOrigin!.count > 0
            )
        })
    }

    public func loadProjectRelations() {
        for project in projects {
            if let parent = getProjectBy(url: project.url.deletingLastPathComponent()) {
                if project.isTrash { continue }
                
                project.parent = parent
                
                if parent.child.filter({ $0.url == project.url }).count == 0 {
                    parent.child.append(project)
                }
                
                parent.child = parent.child.sorted(by: { $0.settings.priority < $1.settings.priority })
            }
        }
    }
    
    public func saveCachedTree() {
        guard let cacheDir = getCacheDir() else { return }
        
        var urls =
            getNonSystemProjects()
            .sorted(by: {
                $0.url.path.components(separatedBy: "/").count < $1.url.path.components(separatedBy: "/").count
            })
            .compactMap({ $0.url })
        
        // Deduplicate
        let deduplicatedUrls = urls.reduce(into: [String: URL]()) { result, object in
            result[object.path] = object
        }.values
        
        urls = Array(deduplicatedUrls)
        
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: urls, requiringSecureCoding: true) {
            let url = cacheDir.appendingPathComponent("sidebarTree")
            
            do {
                try data.write(to: url)
                print("B. Sidebar tree caching is finished")
            } catch {
                print("Sidebar caching error")
            }
        }
    }
    
    public func getCachedTree() -> [URL]? {
        guard let cacheDir = getCacheDir() else { return nil }
        let url = cacheDir.appendingPathComponent("sidebarTree")
        
        if let data = try? Data(contentsOf: url), let urls = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL] {
            return urls
        }
        
        return nil
    }
    
    public func removeCachedTree() {
        guard let cacheDir = getCacheDir() else { return }
        let url = cacheDir.appendingPathComponent("sidebarTree")
        
        try? FileManager.default.removeItem(at: url)
    }
    
    public func cleanCachedTree(url: URL) {
        guard let urls = getCachedTree() else { return }
        let cleanList = urls.filter({ !$0.path.startsWith(string: url.path) })
        
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: cleanList, requiringSecureCoding: false) {
            if let cacheDir = getCacheDir() {
                let url = cacheDir.appendingPathComponent("sidebarTree")
                
                do {
                    try data.write(to: url)
                } catch {
                    print("Sidebar caching error")
                }
            }
        }
    }
    
    public func getSortedProjects() -> [Project] {
        return self.projects.sorted(by: {$0.url.path < $1.url.path})
    }
}

extension String: Error {}
