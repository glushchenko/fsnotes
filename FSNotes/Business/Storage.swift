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
    public var tags = [String]()

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
        let bookmark = SandboxBookmark.sharedInstance()
        bookmarks = bookmark.load()
        
        guard let url = UserDefaultsManagement.storageUrl else { return }

        var name = url.lastPathComponent
        if let iCloudURL = getCloudDrive(), iCloudURL == url {
            name = "iCloud Drive"
        }

        let project = Project(url: url, label: name, isRoot: true, isDefault: true)

        #if os(iOS)
            projects.append(project)

            for bookmark in bookmarks {
                let externalProject = Project(url: bookmark, label: bookmark.lastPathComponent, isTrash: false, isRoot: true, isDefault: false, isArchive: false, isExternal: true)
                
                projects.append(externalProject)
            }

            #if NOT_EXTENSION
                checkTrashForVolume(url: project.url)
            #endif

            return
        #endif

        _ = add(project: project)
        
        checkTrashForVolume(url: project.url)

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
            
            let project = Project(url: url, label: url.lastPathComponent, isRoot: true)
            _ = add(project: project)
        }

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
        let parentPath = url.path + "/i/"
        let filesPath = url.path + "/files/"
        
        if let subFolders = getSubFolders(url: url) {
            for subFolder in subFolders {
                if (subFolder as URL).resolvingSymlinksInPath() == UserDefaultsManagement.archiveDirectory {
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
                    surl.lastPathComponent != "files",
                    !surl.path.contains(".Trash"),
                    !surl.path.contains("Trash"),
                    !surl.path.contains("/."),
                    !surl.path.contains(parentPath),
                    !surl.path.contains(filesPath),
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
        var trashURL = getTrash(url: url)

        do {
            if let trashURL = trashURL {
                try FileManager.default.contentsOfDirectory(atPath: trashURL.path)
            } else {
                throw "Trash not found"
            }
        } catch {
            guard let trash = getDefault()?.url.appendingPathComponent("Trash") else { return }

            var isDir = ObjCBool(false)
            if !FileManager.default.fileExists(atPath: trash.path, isDirectory: &isDir) && !isDir.boolValue {
                do {
                    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: false, attributes: nil)

                    print("New trash created: \(trash)")
                } catch {
                    print("Trash dir error: \(error)")
                }
            }

            trashURL = trash
        }

        if let trashURL = trashURL {
            guard !projectExist(url: trashURL) else { return }
        
            let project = Project(url: trashURL, isTrash: true)
            projects.append(project)
        }
    }
    
    private func getCloudDrive() -> URL? {
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents").resolvingSymlinksInPath() {
            
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

        if !projects.contains(project) {
            projects.append(project)
            added.append(project)
        }

        if project.isRoot && project.url != UserDefaultsManagement.archiveDirectory {
            let addedSubProjects = chechSub(url: project.url, parent: project)
            added = added + addedSubProjects
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

    public func loadProjects(withTrash: Bool = true, skipRoot: Bool = false) {
        if !skipRoot {
            noteList.removeAll()
        }

        for project in projects {
            if project.isTrash && !withTrash {
                continue
            }

            if project.isRoot && skipRoot {
                continue
            }

            loadLabel(project)
        }
    }

    func loadDocuments(tryCount: Int = 0, completion: @escaping () -> Void) {
        _ = restoreCloudPins()

        let count = self.noteList.count
        var i = 0

        #if os(iOS)
        for note in self.noteList {
            note.load()
            i += 1
            if i == count {
                print("Loaded notes: \(count)")
                completion()
            }
        }
        #endif

        self.noteList = self.sortNotes(noteList: self.noteList, filter: "")

        guard !checkFirstRun() else {
            if tryCount == 0 {
                loadProjects()
                loadDocuments(tryCount: 1) {}
                return
            }
            return
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
        let sortDirection = project?.sortDirection ?? (UserDefaultsManagement.sortDirection ? .desc : .asc)
        let sort = project?.sortBy ?? UserDefaultsManagement.sort

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
            let url = document.0 as URL

            #if os(OSX)
                if let currentNoteURL = EditTextView.note?.url,
                    currentNoteURL == url {
                    continue
                }
            #endif

            let note = Note(url: url.resolvingSymlinksInPath(), with: item)
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

            if loadContent {
                note.load()
            }

            if note.isPinned {
                pinned += 1
            }

            if note.isTextBundle() {
                let full = note.url.appendingPathComponent("text.markdown")

                if !FileManager.default.fileExists(atPath: full.path) {
                    continue
                }
            }

            noteList.append(note)
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
        noteList.removeAll(where: { $0.isTrash() })

        for project in projects {
            if project.isTrash {
                self.loadLabel(project, loadContent: true)
            }
        }
    }

    public func readDirectory(_ url: URL) -> [(URL, Date, Date)] {
        let url = url.resolvingSymlinksInPath()

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
            print("Storage not found, url: \(url) – \(error)")
        }
        
        return []
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

    public func removeTagV2(_ string: String) -> Bool {
        if noteList.filter({ $0.tags.contains(string) && !$0.isTrash() }).count < 2 {
            if let i = tags.firstIndex(of: string) {
                tags.remove(at: i)
                return true
            }
        }

        return false
    }

    public func addTagV2(_ string: String) {
        if !tags.contains(string) {
            tags.append(string)
        }
    }

    public func getTagsV2() -> [String] {
        let tags = self.tags + self.tagNames
        
        return tags.sorted { $0 < $1 }
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
            
            let files =
                directoryFiles.filter {
                    !self.isDownloaded(url: $0)
                }

            let images = files.map{
                url in (
                    url,
                    (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                        )?.contentModificationDate ?? Date.distantPast,
                    (try? url.resourceValues(forKeys: [.creationDateKey])
                        )?.creationDate ?? Date.distantPast
                )
            }

            print("Start downloads: \(images.count)")
            
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

    public func isDownloaded(url: URL) -> Bool {
        var isDownloaded: AnyObject? = nil

        do {
            try (url as NSURL).getResourceValue(&isDownloaded, forKey: URLResourceKey.ubiquitousItemDownloadingStatusKey)
        } catch _ {}

        if isDownloaded as? URLUbiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current {
            return true
        }

        return false
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
            result.compactMap({ Project(url: $0)})

        guard projects.count > 0 else {
            return
        }

        self.projects.removeAll()

        for project in projects {
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
}

extension String: Error {}
