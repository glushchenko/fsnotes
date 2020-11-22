//
//  Project.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import CoreServices

public class Project: Equatable {
    var storage: Storage

    var url: URL

    public var moveSrc: URL?
    public var moveDst: URL?

    public var label: String
    var isTrash: Bool
    var isCloudDrive: Bool = false
    var isRoot: Bool
    var parent: Project?
    var isDefault: Bool
    var isArchive: Bool

    public var isVirtual = false
    public var isExternal: Bool = false

    public var sortDirection: SortDirection = .desc

    public var showInCommon: Bool
    public var showInSidebar: Bool = true

    #if os(iOS)
    public var firstLineAsTitle: Bool = true
    public var sortBy: SortBy = .modificationDate
    #else
    public var firstLineAsTitle: Bool = false
    public var sortBy: SortBy = .none
    #endif

    public var metaCache = [NoteMeta]()
    
    // all notes loaded with cache diff comparsion
    public var isReadyForCacheSaving = false

    // if notes loaded from cache validation with fs needed
    public var cacheUsedDiffValidationNeeded = false
    
    init(storage: Storage,
         url: URL,
         label: String? = nil,
         isTrash: Bool = false,
         isRoot: Bool = false,
         parent: Project? = nil,
         isDefault: Bool = false,
         isArchive: Bool = false,
         isExternal: Bool = false,
         isVirtual: Bool = false
    ) {
        self.storage = storage
        self.url = url.standardized
        self.isTrash = isTrash
        self.isRoot = isRoot
        self.parent = parent
        self.isDefault = isDefault
        self.isArchive = isArchive
        self.isExternal = isExternal
        self.isVirtual = isVirtual

        showInCommon = (isTrash || isArchive) ? false : true

        #if os(iOS)
        if isRoot && isDefault {
            showInSidebar = false
        }
        #endif

        self.label = String()

        loadLabel(label)
        isCloudDrive = isCloudDriveFolder(url: url)
        loadSettings()
    }

    public static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.url == rhs.url
    }

    public func loadLabel(_ label: String? = nil) {
        if let l = label {
            self.label = l
        } else {
            self.label = url.lastPathComponent
        }

        var localizedName: AnyObject?
        try? (url as NSURL).getResourceValue(&localizedName, forKey: URLResourceKey.localizedNameKey)
        if let name = localizedName as? String, name.count > 0 {
            self.label = name
        }
    }

    public func getCacheURL() -> URL? {
        guard let cacheDir = storage.getCacheDir() else { return nil }

        let key = self.url.path.md5
        let cacheFile = cacheDir.appendingPathComponent(key + ".cache")

        return cacheFile
    }

    public func saveCache() {
        guard isReadyForCacheSaving, let cacheURL = getCacheURL() else { return }

        let notes = storage.noteList.filter({ $0.project == self })

        for note in notes {
            if note.isEncrypted() {
                _ = note.lock()
            }
        }

        let meta = notes.map({ $0.getMeta() })
        let jsonEncoder = JSONEncoder()

        do {
            let data = try jsonEncoder.encode(meta)
            try data.write(to: cacheURL)

            print("Cache saved for: \(self.label)")
        } catch {
            print("Serialization error.")
        }
    }

    public func removeCache() {
        guard let cacheURL = getCacheURL() else { return }

        do {
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                try FileManager.default.removeItem(at: cacheURL)

                print("Cache removed successfully at: \(cacheURL.path)")
            }
        } catch {
            print("Cache removing error: \(error)")
        }
    }

    public func loadCache() {
        guard let cacheURL = getCacheURL() else { return }

        if let data = try? Data(contentsOf: cacheURL) {
            let decoder = JSONDecoder()

            do {
                metaCache = try decoder.decode(Array<NoteMeta>.self, from: data)
            } catch {
                print(error)
            }
        }
    }

    public func fetchNotes() -> [Note] {
        var notes = [Note]()
        let documents = fetchAllDocuments(at: url)

        for document in documents {
            let url = (document.0 as URL).standardized
            let modified = document.1
            let created = document.2

            if (url.absoluteString.isEmpty) {
                continue
            }

            let note = Note(url: url, with: self, modified: modified, created: created)

            if note.isTextBundle() && !note.isFullLoadedTextBundle() {
                continue
            }

            notes.append(note)
        }

        return notes
    }

    public func loadNotes() {
        loadCache()

        var notes = [Note]()
        if !metaCache.isEmpty {
            for noteMeta in metaCache {
                let note = Note(meta: noteMeta, project: self)
                notes.append(note)
            }

            self.cacheUsedDiffValidationNeeded = true
        } else {
            notes = fetchNotes()
        }

        notes = loadPins(for: notes)
        storage.noteList.append(contentsOf: notes)
    }

    public func fetchAllDocuments(at url: URL) -> [(URL, Date, Date)] {
        let url = url.standardized

        do {
            let directoryFiles =
                try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .typeIdentifierKey], options:.skipsHiddenFiles)

            return
                directoryFiles.filter {
                    storage.allowedExtensions.contains($0.pathExtension)
                    || storage.isValidUTI(url: $0)
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

    public func loadPins(for notes: [Note]) -> [Note] {
        let keyStore = NSUbiquitousKeyValueStore()
        keyStore.synchronize()

        if let names = keyStore.array(forKey: "co.fluder.fsnotes.pins.shared") as? [String] {
            for name in names {
                if let note = notes.first(where: { $0.name == name }) {
                    note.isPinned = true
                }
            }
        }

        return notes
    }
    
    func fileExist(fileName: String, ext: String) -> Bool {        
        let fileURL = url.appendingPathComponent(fileName + "." + ext)
        
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    private func isCloudDriveFolder(url: URL) -> Bool {
        if let iCloudDocumentsURL =
            FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents", isDirectory: true)
                .standardized
        {
            
            if FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil), url.path.contains(iCloudDocumentsURL.path) {
                return true
            }
        }
        
        return false
    }
    
    public func getParent() -> Project {
        if isRoot {
            return self
        }
        
        if let parent = self.parent {
            return parent.getParent()
        }
        
        return self
    }
    
    public func getFullLabel() -> String {
        if isRoot  {
            if isExternal {
                return "External › " + label
            }
            
            return label
        }

        if isTrash {
            return "Trash"
        }

        if isArchive {
            return label
        }
        
        return "FSNotes › \(label)"
    }

    public func saveSettings() {
        let data = [
            "sortBy": sortBy.rawValue,
            "sortDirection": sortDirection.rawValue,
            "showInCommon": showInCommon,
            "showInSidebar": showInSidebar,
            "firstLineAsTitle": firstLineAsTitle
        ] as [String : Any]

        #if os(OSX)
        if let relativePath = getRelativePath() {
            let keyStore = NSUbiquitousKeyValueStore()
            let key = relativePath.count == 0 ? "root-directory" : relativePath

            keyStore.set(data, forKey: key)
            keyStore.synchronize()
            return
        }
        #endif

        UserDefaultsManagement.shared?.set(data, forKey: url.path.md5)
    }

    public func loadSettings() {
        if label == "Welcome" {
            sortBy = .title
            sortDirection = .asc
        }

        #if os(OSX)
        if let relativePath = getRelativePath() {
            let keyStore = NSUbiquitousKeyValueStore()
            let key = relativePath.count == 0 ? "root-directory" : relativePath

            if let settings = keyStore.dictionary(forKey: key) {
                if let common = settings["showInCommon"] as? Bool {
                    self.showInCommon = common
                }

                if let sidebar = settings["showInSidebar"] as? Bool {
                    self.showInSidebar = sidebar
                }

                if let sortString = settings["sortBy"] as? String, let sort = SortBy(rawValue: sortString) {
                    if sort != .none {
                        sortBy = sort

                        if let directionString = settings["sortDirection"] as? String, let direction = SortDirection(rawValue: directionString) {
                            sortDirection = direction
                        }
                    }
                }

                if let firstLineAsTitle = settings["firstLineAsTitle"] as? Bool {
                    self.firstLineAsTitle = firstLineAsTitle
                } else {
                    self.firstLineAsTitle = UserDefaultsManagement.firstLineAsTitle
                }
            }
            return
        }
        #endif

        if let settings = UserDefaultsManagement.shared?.object(forKey: url.path.md5) as? NSObject {
            if let common = settings.value(forKey: "showInCommon") as? Bool {
                self.showInCommon = common
            }

            if let sidebar = settings.value(forKey: "showInSidebar") as? Bool {
                self.showInSidebar = sidebar
            }

            if let sortString = settings.value(forKey: "sortBy") as? String,
                let sort = SortBy(rawValue: sortString)
            {
                if sort != .none {
                    sortBy = sort

                    if let directionString = settings.value(forKey: "sortDirection") as? String,
                        let direction = SortDirection(rawValue: directionString) {
                        sortDirection = direction
                    }
                }
            }

            if let firstLineAsTitle = settings.value(forKey: "firstLineAsTitle") as? Bool {
                self.firstLineAsTitle = firstLineAsTitle
            } else {
                self.firstLineAsTitle = UserDefaultsManagement.firstLineAsTitle
            }

            return
        }

        self.firstLineAsTitle = UserDefaultsManagement.firstLineAsTitle
    }

    public func getRelativePath() -> String? {
        if let iCloudRoot =  FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents").standardized {

            let path = url.path.replacingOccurrences(of: iCloudRoot.path, with: "")
            return path.md5
        }

        return nil
    }

    public func getGitPath() -> String? {
        if isArchive || parent == nil {
            return nil
        }

        let parentURL = getParent().url
        let relative = url.path.replacingOccurrences(of: parentURL.path, with: "")
        
        if relative.first == "/" {
            return String(relative.dropFirst())
        }

        if relative == "" {
            return nil
        }

        return relative
    }

    public func createImagesDirectory() {
        do {
            try FileManager.default.createDirectory(at: url.appendingPathComponent("i"), withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }
    }

    public func remove() {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print(error)
        }
    }

    public func create() {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }
    }

    public func getShortSign() -> String {
        return String(getParent().url.path.md5.prefix(4))
    }

    public func getAllTags() -> [String] {
        let notes = Storage.sharedInstance().noteList.filter({ $0.project == self })

        var tags: Set<String> = []
        for note in notes {
            for tag in note.tags {
                if !tags.contains(tag) {
                    tags.insert(tag)
                }
            }
        }

        return Array(tags)
    }

    public func checkFSAndMemoryDiff() -> ([Note], [Note], [Note]) {
        var foundRemoved = [Note]()
        var foundAdded = [Note]()
        var foundChanged = [Note]()

        let memoryNotes = Storage.shared().noteList.filter({ $0.project == self })
        let fileSystemNotes = fetchNotes()

        let cachedNotes = Set(memoryNotes.map({ $0.url }))
        let currentNotes = Set(fileSystemNotes.map({ $0.url }))

        let removed = cachedNotes.subtracting(currentNotes)
        let added = currentNotes.subtracting(cachedNotes)

        for removeURL in removed {
            if let note = memoryNotes.first(where: { $0.url == removeURL }) {
                foundRemoved.append(note)
                storage.noteList.removeAll(where: { $0 == note })
            }
        }

        for addURL in added {
            if let note = fileSystemNotes.first(where: { $0.url == addURL }) {
                note.load()
                foundAdded.append(note)
                storage.noteList.append(note)
            }
        }

        for memoryNote in memoryNotes {
            if let note = fileSystemNotes.first(where: { $0.url == memoryNote.url }) {
                if memoryNote.modifiedLocalAt != note.modifiedLocalAt {
                    memoryNote.forceLoad()
                    foundChanged.append(memoryNote)
                }
            }
        }

        isReadyForCacheSaving = true
        return (foundRemoved, foundAdded, foundChanged)
    }
}
