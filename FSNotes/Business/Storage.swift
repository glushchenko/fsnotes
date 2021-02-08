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
    
    public var noteList = [Note]()
    private var projects = [Project]()
    private var imageFolders = [URL]()

    public var tagNames = [String]()
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

    private var bookmarks = [URL]()
    public var shouldMovePrompt = false

    private var trashURL = URL(string: String())
    private var archiveURL = URL(string: String())

    private let lastNewsDate = "2020-06-20"
    public var isFinishedTagsLoading = false
    public var isCrashedLastTime = false

    private var relativeInlineImagePaths = [String]()

    init() {
        let storageType = UserDefaultsManagement.storageType
        let bookmark = SandboxBookmark.sharedInstance()
        bookmarks = bookmark.load()
        
        guard let url = UserDefaultsManagement.storageUrl else { return }

        if UserDefaultsManagement.storageType != storageType
            && storageType == .local
            && UserDefaultsManagement.storageType == .iCloudDrive {
            shouldMovePrompt = true
        }

        initWelcome(storage: url)

        var name = url.lastPathComponent
        if let iCloudURL = getCloudDrive(), iCloudURL == url {
            name = "iCloud Drive"
        }

        let project = Project(storage: self, url: url, label: name, isRoot: true, isDefault: true)

        assignTree(for: project)
        assignTrash(by: project.url)

        for url in bookmarks {
            if url.pathExtension == "css" {
                continue
            }

            guard !projectExist(url: url) else {
                continue
            }

            if url == UserDefaultsManagement.archiveDirectory
                || url == UserDefaultsManagement.gitStorage {
                continue
            }

            let project = Project(storage: self, url: url, label: url.lastPathComponent, isRoot: true)
            assignTree(for: project)
        }

        let archiveLabel = NSLocalizedString("Archive", comment: "Sidebar label")

        if let archive = UserDefaultsManagement.archiveDirectory {
            let project = Project(storage: self, url: archive, label: archiveLabel, isRoot: false, isDefault: false, isArchive: true)
            assignTree(for: project)
        }
    }

    init(micro: Bool) {
        guard let url = getRoot() else { return }
        removeCachesIfCrashed()

        let project =
            Project(
                storage: self,
                url: url,
                label: "iCloud Drive",
                isRoot: true,
                isDefault: true
            )

        projects.append(project)

        assignTrash(by: project.url)
        assignArchive()
        assignBookmarks()

        loadCachedProjects()
        checkWelcome()
    }

    public static func shared() -> Storage {
        guard let storage = self.instance else {
            self.instance = Storage(micro: true)
            return self.instance!
        }
        return storage
    }

    public func loadCachedProjects() {
        let urls = UserDefaultsManagement.projects

        for url in urls {
            _ = addProject(url: url)
        }
    }

    public func getRoot() -> URL? {
        #if targetEnvironment(simulator)
            return UserDefaultsManagement.storageUrl
        #endif

        let ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil)

        guard let iCloudDocumentsURL = ubiquityContainer?
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
            UserDefaultsManagement.projects = [URL]()
            
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

    public func getRootProject() -> Project? {
        return projects.first(where: { $0.isRoot })
    }

    public func getDefault() -> Project? {
        return projects.first(where: { $0.isDefault })
    }
    
    public func getRootProjects() -> [Project] {
        return projects.filter({ $0.isRoot && $0.url != UserDefaultsManagement.archiveDirectory }).sorted(by: { $0.label.lowercased() < $1.label.lowercased() })
    }

    public func getDefaultTrash() -> Project? {
        return projects.first(where: { $0.isTrash })
    }
    
    private func chechSub(url: URL, parent: Project) -> [Project] {
        var added = [Project]()

        if let urls = getSubFolders(url: url) {
            for url in urls {
                let standardizedURL = (url as URL).standardized

                if let project = addProject(url: standardizedURL, parent: parent) {
                    added.append(project)
                }
            }
        }
        
        return added
    }

    public func addProject(url: URL, parent: Project? = nil) -> Project? {
        var parent = parent

        if parent == nil {
            let parentUrl = url.deletingLastPathComponent()
            guard let project = getProjectBy(url: parentUrl) else {
                return nil
            }

            parent = project
        }

        if url.standardized ==
            UserDefaultsManagement.archiveDirectory {
            return nil
        }

        if projects.count > 100 {
            return nil
        }

        guard !projectExist(url: url),
            url.lastPathComponent != "i",
            url.lastPathComponent != "files",
            !url.path.contains(".git"),
            !url.path.contains(".Trash"),
            !url.path.contains(".cache"),
            !url.path.contains("Trash"),
            !url.path.contains("/."),
            !url.path.contains(".textbundle") else {
            return nil
        }

        let project = Project(
            storage: self,
            url: url,
            label: url.lastPathComponent,
            parent: parent
        )

        projects.append(project)

        return project
    }

    private func assignTrash(by url: URL) {
        let trashURL = url.appendingPathComponent("Trash", isDirectory: true)

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
        projects.append(project)

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

    public func assignTree(for project: Project, completion: ((_ notes: [Project]) -> ())? = nil) {
        var added = [Project]()

        if !projects.contains(project) {
            projects.append(project)
            added.append(project)
        }

        if project.isRoot && project.url != UserDefaultsManagement.archiveDirectory {
            let addedSubProjects = chechSub(url: project.url, parent: project)
            added = added + addedSubProjects
        }

        if let completion = completion {
            completion(added)
        }
    }

    public func loadAllTags() {
        for note in noteList {
            note.load()

            if !note.isTrash() && !note.project.isArchive {
                _ = note.loadTags()
            }
        }

        isFinishedTagsLoading = true
    }

    public func loadAllTagsOnly() {
        for note in noteList {
            if !note.isTrash() && !note.project.isArchive {
                _ = note.loadTags()
            }
        }

        isFinishedTagsLoading = true
    }

    public func getProjectDocuments(project: Project) -> [URL] {
        return readDirectory(project.url).map({ $0.0 as URL })
    }

    public func assignBookmarks() {
        let bookmark = SandboxBookmark.sharedInstance()
        bookmarks = bookmark.load()
        for bookmark in bookmarks {
            let externalProject =
                Project(storage: self,
                        url: bookmark,
                        label: bookmark.lastPathComponent,
                        isTrash: false,
                        isRoot: true,
                        isDefault: false,
                        isArchive: false,
                        isExternal: true)

            projects.append(externalProject)
        }
    }

    public func assignArchive() {
        if let archive = UserDefaultsManagement.archiveDirectory {
            let archiveLabel = NSLocalizedString("Archive", comment: "Sidebar label")
            let project = Project(
                storage: self,
                url: archive,
                label: archiveLabel,
                isRoot: false,
                isDefault: false,
                isArchive: true
            )
            projects.append(project)

            self.archiveURL = archive
        }
    }

    public func getArchive() -> Project? {
        if let project = projects.first(where: { $0.isArchive }) {
            return project
        }
        
        return nil
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

    public func loadProjects(withTrash: Bool = true, skipRoot: Bool = false, withArchive: Bool = true) {
        if !skipRoot {
            noteList.removeAll()
        }

        for project in projects {
            if project.isTrash && !withTrash {
                continue
            }

            if project.isRoot && !project.isExternal && skipRoot {
                continue
            }

            if project.isArchive && !withArchive {
                continue
            }

            loadLabel(project)
        }
    }

    public func loadDocuments() {
        let startingPoint = Date()

        _ = restoreCloudPins()

        for note in noteList {
            note.fastLoad()
        }

        print("Loaded \(noteList.count) notes for \(startingPoint.timeIntervalSinceNow * -1) seconds")

        noteList = sortNotes(noteList: noteList, filter: "")
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
            && !$0.isArchive
        })
    }

    public func getAvailableProjects() -> [Project] {
        return projects.filter({
            !$0.isDefault
            && !$0.isTrash
            && !$0.isArchive
            && $0.showInSidebar
        })
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
            }
            
            return sortQuery(note: $0, next: $1, project: project)
        })
    }
    
    private func sortQuery(note: Note, next: Note, project: Project?) -> Bool {
        var sortDirection: SortDirection
        var sort: SortBy

        if let project = project, project.sortBy != .none {
            sortDirection = project.sortDirection
        } else {
            sortDirection = UserDefaultsManagement.sortDirection ? .desc : .asc
        }
        
        if let sortBy = project?.sortBy, sortBy != .none {
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
                return sortDirection == .asc && note.title.lowercased() < next.title.lowercased() || sortDirection == .desc && note.title.lowercased() > next.title.lowercased()
            }
        }
        
        return note.isPinned && !next.isPinned
    }

    func loadLabel(_ item: Project, loadContent: Bool = false) {
        let documents = readDirectory(item.url)

        for document in documents {
            #if os(OSX)
            if let url = EditTextView.note?.url,
                url == document.0 {
                continue
            }
            #endif

            let note = Note(url: document.0, with: item)
            if document.0.pathComponents.isEmpty {
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
                note.loadPreviewInfo()
            #else
                if loadContent {
                    note.load()
                }
            #endif

            if note.isTextBundle() && !note.isFullLoadedTextBundle() {
                continue
            }

            noteList.append(note)
        }
    }
    
    public func unload(project: Project) {
        let notes = noteList.filter({ $0.project == project })
        for note in notes {
            if let i = noteList.firstIndex(where: {$0 === note}) {
                noteList.remove(at: i)
            }
        }
    }

    public func reLoadTrash() {
        noteList.removeAll(where: { $0.isTrash() })

        for project in projects {
            if project.isTrash {
                self.loadLabel(project, loadContent: true)
            }
        }
    }

    public func readDirectory(_ url: URL) -> [(URL, Date, Date)] {
        let url = url.standardized

        do {
            let files =
                try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [
                        .contentModificationDateKey,
                        .creationDateKey,
                        .typeIdentifierKey
                    ],
                    options:.skipsHiddenFiles
                )
            
            return
                files.filter {
                    allowedExtensions.contains($0.pathExtension)
                    || self.isValidUTI(url: $0)
                }.map {
                    url in (
                        url,
                        (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                            )?.contentModificationDate ?? Date.distantPast,
                        (try? url.resourceValues(forKeys: [.creationDateKey])
                            )?.creationDate ?? Date.distantPast
                    )
                }.map {
                    if $0.0.pathExtension == "textbundle" {
                        return (
                            URL(fileURLWithPath: $0.0.path, isDirectory: false),
                            $0.1,
                            $0.2
                        )
                    }

                    return $0
                }
            
        } catch {
            print("Storage not found, url: \(url) – \(error)")
        }
        
        return []
    }

    public func isValidNote(url: URL) -> Bool {
        return allowedExtensions.contains(url.pathExtension) || isValidUTI(url: url)
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
    
    func getBy(url: URL) -> Note? {
        let standardized = url.standardized

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

    public func getTitles(by word: String? = nil) -> [String]? {
        var notes = noteList

        if let word = word {
            notes = notes
                .filter{
                    $0.title.contains(word) && $0.project.firstLineAsTitle
                        || $0.fileName.contains(word) && !$0.project.firstLineAsTitle

                }
                .filter({ !$0.isTrash() })

            guard notes.count > 0 else { return nil }

            var titles = notes.map{ String($0.project.firstLineAsTitle ? $0.title : $0.fileName) }

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
            .map{ String($0.project.firstLineAsTitle ? $0.title : $0.fileName ) }
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

                    if (url as URL).isHidden() {
                        continue
                    }

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
            })

        var fin = [URL]()
        var i = 0

        for url in urls {
            i = i + 1

            do {
                var isDirectoryResourceValue: AnyObject?
                try (url as NSURL).getResourceValue(&isDirectoryResourceValue, forKey: URLResourceKey.isDirectoryKey)

                var isPackageResourceValue: AnyObject?
                try (url as NSURL).getResourceValue(&isPackageResourceValue, forKey: URLResourceKey.isPackageKey)

                if isDirectoryResourceValue as? Bool == true,
                    isPackageResourceValue as? Bool == false {
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
    
    public func getTags() -> [String] {
        return tagNames.sorted { $0 < $1 }
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

    #if os(iOS)
    public func createProject(name: String) -> Project {
        let storageURL = UserDefaultsManagement.storageUrl!

        var url = storageURL.appendingPathComponent(name)

        if FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
            url = storageURL.appendingPathComponent("\(name) \(String(Date().toMillis()))")
        }

        let project = Project(storage: self, url: url)
        project.createImagesDirectory()

        assignTree(for: project)
        return project
    }
    #endif

    public func initNote(url: URL) -> Note? {
        guard let project = self.getProjectByNote(url: url) else { return nil }

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

    public func loadPins(notes: [Note]) {
        let keyStore = NSUbiquitousKeyValueStore()
        keyStore.synchronize()

        var success = [Note]()

        guard let names = keyStore.array(forKey: "co.fluder.fsnotes.pins.shared") as? [String]
            else { return }

        for note in notes {
            if names.contains(note.name) {
                note.addPin(cloudSave: false)
                success.append(note)
            }
        }
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
                if let note = getBy(name: name), !note.isPinned {
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
                project.isRoot = true
                project.isDefault = true
                project.label = NSLocalizedString("Inbox", comment: "") 
            }

            self.projects.append(project)
        }
    }

    public func trashItem(url: URL) -> URL? {
        guard let trashURL = Storage.sharedInstance().getDefaultTrash()?.url else { return nil }

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

    public func initWelcome(storage: URL) {
        guard UserDefaultsManagement.copyWelcome else { return }

        guard let bundlePath = Bundle.main.path(forResource: "Welcome", ofType: ".bundle") else { return }

        let bundle = URL(fileURLWithPath: bundlePath)
        let url = storage.appendingPathComponent("Welcome")

        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: bundle.path)
            for file in files {
                try FileManager.default.copyItem(atPath: "\(bundle.path)/\(file)", toPath: "\(url.path)/\(file)")
            }
        } catch {
            print("Initial copy error: \(error)")
        }
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
    }

    public func cleanUnlocked() {
        noteList.filter({ $0.isUnlocked() }).map({ $0.cleanOut() })
    }

    private func checkWelcome() {
        guard UserDefaultsManagement.copyWelcome else { return }
        guard noteList.isEmpty else { return }

        let welcomeFileName = "FSNotes 4.0 for iOS.textbundle"

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
        let file = "FSNotes 4.0 Change Log.textbundle"

        guard let src = Bundle.main.resourceURL?.appendingPathComponent("Initial/\(file)") else { return nil }

        return src
    }

    public func fetchNonSystemProjectURLs() -> [URL] {
        var projectURLs = [URL]()

        if let main = getDefault(),
            let urls = fetchAllDirectories(url: main.url)
        {
            for url in urls {
                let standardizedURL = (url as URL).standardized

                if standardizedURL == archiveURL
                    || standardizedURL == trashURL
                    || standardizedURL == main.url
                {
                    continue
                }

                projectURLs.append(standardizedURL)
            }
        }

        let sandbox = SandboxBookmark.sharedInstance()
        let urls = sandbox.load()

        for url in urls {
            if !projectURLs.contains(url) {
                projectURLs.append(url)
            }
        }

        return projectURLs
    }

    public func checkFSAndMemoryDiff() -> ([Project], [Project]) {
        var foundRemoved = [Project]()
        var foundAdded = [Project]()

        let memoryProjects = Storage.shared().getNonSystemProjects()
        let fileSystemURLs = fetchNonSystemProjectURLs()

        let cachedProjects = Set(memoryProjects.compactMap({ $0.url }))
        let currentProjects = Set(fileSystemURLs)

        let removed = cachedProjects.subtracting(currentProjects)
        let added = currentProjects.subtracting(cachedProjects)

        for removeURL in removed {
            if let project = memoryProjects.first(where: { $0.url == removeURL }) {
                foundRemoved.append(project)
                remove(project: project)
            }
        }

        for addURL in added {
            let project = Project(storage: self, url: addURL)
            foundAdded.append(project)
            projects.append(project)
        }

        return (foundRemoved, foundAdded)
    }

    public func importNote(url: URL) -> Note? {
        guard getBy(url: url) == nil, let note = initNote(url: url) else { return nil }

        note.loadFileWithAttributes()

        if note.isTextBundle() && !note.isFullLoadedTextBundle() {
            return nil
        }

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
}

extension String: Error {}
