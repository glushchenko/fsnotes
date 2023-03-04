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

    public var settings: ProjectSettings
    
    // Settings
    
    public var sortBy: SortBy = .none
    public var sortDirection: SortDirection = .desc
    public var showInCommon: Bool
    public var showInSidebar: Bool = true
    public var showNestedFoldersContent: Bool = true
    public var firstLineAsTitle: Bool = true
    public var priority: Int = 0
    
    public var metaCache = [NoteMeta]()
    
    // all notes loaded with cache diff comparsion
    public var isReadyForCacheSaving = false

    // if notes loaded from cache validation with fs needed
    public var cacheUsedDiffValidationNeeded = false

    public var child = [Project]()
    public var isExpanded = false
    
    public var isEncrypted = false
    public var password: String?
    
    public var settingsList: Data?
    public var settingsKey = String()
    
    public var commitsCache = [String: [String]]()

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

        settings = ProjectSettings()
    
        if isTrash || isArchive {
            settings.showInCommon = false
        }
        
        // temp
        showInCommon = !(isTrash || isArchive)

        #if os(iOS)
        if isRoot && isDefault {
            showInSidebar = false
        }
        #endif

        self.label = String()
        settingsKey = getSettingsKey()
        
        loadLabel(label)
        isCloudDrive = isCloudDriveFolder(url: url)
        
        // Init sort for default project
        if self.label == "Welcome" {
            sortBy = .title
            sortDirection = .asc
        }
        
        if let settings = getSettings() {
            self.settings = settings
        }
    }
    
    public func saveSettings() {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: settings, requiringSecureCoding: false) else { return }
        
        let key = "es.fsnot.project-settings-\(getSettingsKey())"
        
        #if CLOUDKIT || os(iOS)
            let keyStore = NSUbiquitousKeyValueStore()
            keyStore.set(data, forKey: key)
            keyStore.synchronize()
        #else
            if let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
               let url = documentDir.appendingPathComponent(key) {
                data.write(to: url)
            }
        #endif
    }
    
    public func getSettings() -> ProjectSettings? {
        let key = "es.fsnot.project-settings-\(getSettingsKey())"
        var data: Data?
        
        #if CLOUDKIT || os(iOS)
            let keyStore = NSUbiquitousKeyValueStore()
            data = keyStore.data(forKey: key)
        #else
            if let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
               let url = documentDir.appendingPathComponent(key) {
                data = try? Data(contentsOf: url)
            }
        #endif
        
        if let data = data, let settings = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ProjectSettings.self, from: data) {
            return settings
        }
        
        return nil
    }
    
    public func getSettingsKey() -> String {
        var prefix = String()
        
        // iCloud Documents
        if let path = getCloudDriveRelativePath() {
            prefix = "i\(path)"
            
        // Local documents
        } else if let path = getLocalDocumentsRelativePath() {
            prefix = "l\(path)"
            
        // External
        } else {
            prefix = "e\(url.path)"
        }
        
        return prefix.md5
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
        
        isEncrypted = getEncryptionStatus()
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

    func fileExistCaseInsensitive(fileName: String, ext: String) -> Bool {
        let fileURL = url.appendingPathComponent(fileName + "." + ext)

        if let note = storage.getBy(url: fileURL) {
            return FileManager.default.fileExists(atPath: note.url.path)
        }

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
   
    private func getCloudDriveRelativePath() -> String? {
        if let iCloudDir =
            FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents", isDirectory: true)
                .standardized,
           
            url.path.contains(iCloudDir.path) {
            
            return url.path.replacingOccurrences(of: iCloudDir.path, with: "")
        }
        
        return nil
    }
    
    private func getLocalDocumentsRelativePath() -> String? {
        if let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            url.path.contains(documentDir.path) {
            
            return url.path.replacingOccurrences(of: documentDir.path, with: "")
        }
        
        return nil
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
    
    public func isVisibleInCommon() -> Bool {
        if !showInCommon {
            return false
        }
        
        var parent = self.parent
                
        while parent != nil {
            if let unwrapped = parent?.parent {
                if !unwrapped.showInCommon {
                    return false
                }
                
                parent = unwrapped
                continue
            }
            
            return parent?.showInCommon == true
        }
        
        return showInCommon
    }

    public func getNestedLabel() -> String {
        var project: Project? = self
        var result = String()

        while project != nil {
            if let unwrappedProject = project {
                if result.count > 0 {
                    result = unwrappedProject.label + " › " + result
                } else {
                    result = unwrappedProject.label
                }
                
                project = unwrappedProject.parent
            } else {
                project = nil
            }
        }

        return result
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
    
//    public func loadSettings() {
//        return
//
//        if label == "Welcome" {
//            sortBy = .title
//            sortDirection = .asc
//        }
//
//    #if os(OSX)
//        var settings: [String : Any]?
//
//        if let relativePath = getRelativePath() {
//            let key = relativePath.count == 0 ? "root-directory" : relativePath
//
//            if let result = NSUbiquitousKeyValueStore().dictionary(forKey: key) {
//                settings = result
//            }
//        } else if let data = self.settingsList,
//            let result = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String : Any] {
//            settings = result
//        }
//
//        guard let settings = settings else { return }
//
//        if let common = settings["showInCommon"] as? Bool {
//            self.showInCommon = common
//        }
//
//        if let sidebar = settings["showInSidebar"] as? Bool {
//            self.showInSidebar = sidebar
//        }
//
//        if let sidebar = settings["showNestedFoldersContent"] as? Bool {
//            self.showNestedFoldersContent = sidebar
//        }
//
//        if let sortString = settings["sortBy"] as? String, let sort = SortBy(rawValue: sortString) {
//            if sort != .none {
//                sortBy = sort
//
//                if let directionString = settings["sortDirection"] as? String, let direction = SortDirection(rawValue: directionString) {
//                    sortDirection = direction
//                }
//            }
//        }
//
//        if let firstLineAsTitle = settings["firstLineAsTitle"] as? Bool {
//            self.firstLineAsTitle = firstLineAsTitle
//        } else {
//            self.firstLineAsTitle = UserDefaultsManagement.firstLineAsTitle
//        }
//
//        if let priority = settings["priority"] as? Int {
//            self.priority = priority
//        }
//
//        if let origin = settings["gitOrigin"] as? String {
//            self.gitOrigin = origin
//        }
//
//        return
//    #endif
//
//        if let settings = UserDefaultsManagement.shared?.object(forKey: getPathChecksum()) as? NSObject {
//            if let common = settings.value(forKey: "showInCommon") as? Bool {
//                self.showInCommon = common
//            }
//
//            if let sidebar = settings.value(forKey: "showInSidebar") as? Bool {
//                self.showInSidebar = sidebar
//            }
//
//            if let sidebar = settings.value(forKey: "showNestedFoldersContent") as? Bool {
//                self.showNestedFoldersContent = sidebar
//            }
//
//            if let sortString = settings.value(forKey: "sortBy") as? String,
//                let sort = SortBy(rawValue: sortString)
//            {
//                if sort != .none {
//                    sortBy = sort
//
//                    if let directionString = settings.value(forKey: "sortDirection") as? String,
//                        let direction = SortDirection(rawValue: directionString) {
//                        sortDirection = direction
//                    }
//                }
//            }
//
//            if let firstLineAsTitle = settings.value(forKey: "firstLineAsTitle") as? Bool {
//                self.firstLineAsTitle = firstLineAsTitle
//            } else {
//                self.firstLineAsTitle = UserDefaultsManagement.firstLineAsTitle
//            }
//
//            if let originString = settings.value(forKey: "gitOrigin") as? String {
//                gitOrigin = originString
//            }
//
//            return
//        }
//
//        self.firstLineAsTitle = UserDefaultsManagement.firstLineAsTitle
//    }

    public func getRelativePath() -> String? {
        if let iCloudRoot =  FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents").standardized {

            let path = url.path.replacingOccurrences(of: iCloudRoot.path, with: "")
            return path.md5
        }

        return nil
    }
    
    public func getPathChecksum() -> String {
        if !UserDefaultsManagement.iCloudDrive, let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            var path = url.path.replacingOccurrences(of: documentDir.path, with: "")
            
            if path == "" {
                path = "Local"
            }
            
            return path.md5
        } else {
            return url.path.md5
        }
    }

    public func getMd5CheckSum() -> String {
        return url.path.md5
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
        let notes = Storage.shared().noteList.filter({ $0.project == self })

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

    public func isExpandable() -> Bool {
        return child.count > 0
    }

    public func getAllChild() -> [Project]? {
        var projects = [Project]()
        projects.append(self)

        for item in child {
            if item.child.count > 0 {
                if let sub = item.getAllChild() {
                    projects.append(contentsOf: sub)
                }
            } else {
                projects.append(item)
            }
        }

        return projects
    }

    public func getHistoryURL() -> URL? {
        let url = storage.getRevisionsHistory()

        return url.appendingPathComponent(getMd5CheckSum())
    }
    
    public func getNotes() -> [Note] {
        return storage.noteList.filter({ $0.project == self })
    }
    
    public func countNotes(contains image: URL) -> Int {
        let notes = getNotes()
        var qty = 0
        for note in notes {
            if let images = note.imageUrl {
                if images.contains(where: { $0.path == image.path }) {
                    qty += 1
                }
            }
        }
        return qty
    }
    
    public func getEncryptionStatusFilePath() -> URL {
        return url.appendingPathComponent(".encrypt", isDirectory: false)
    }
    
    public func getEncryptionStatus() -> Bool {
        let encFolder = getEncryptionStatusFilePath()
        if FileManager.default.fileExists(atPath: encFolder.path) {
            return true
        }
        return false
    }
    
    public func isLocked() -> Bool {
        return password == nil && isEncrypted
    }
    
    public func encrypt(password: String) -> [Note] {
        if isEncrypted {
            return [Note]()
        }
        
        let encFolder = getEncryptionStatusFilePath()
        FileManager.default.createFile(atPath: encFolder.path, contents: nil)
        
        isEncrypted = true
        
        let notes = storage.getNotesBy(project: self)
        var encrypted = [Note]()
        
        for note in notes {
            if note.encrypt(password: password) {
                encrypted.append(note)
            }
        }
        
        return encrypted
    }
    
    public func decrypt(password: String) -> [Note] {
        if !isEncrypted {
            return [Note]()
        }
                
        let notes = storage.getNotesBy(project: self)
        var decrypted = [Note]()
        
        var qty = 0
        for note in notes {
            if note.unEncrypt(password: password) {
                qty += 1
                decrypted.append(note)
            }
        }
        
        guard qty > 0 else { return [Note]() }
        
        let encFolder = getEncryptionStatusFilePath()
        try? FileManager.default.removeItem(at: encFolder)
        
        isEncrypted = false
        
        return decrypted
    }
}
