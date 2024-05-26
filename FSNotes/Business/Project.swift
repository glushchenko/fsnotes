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

    public var label: String
    var isTrash: Bool
    var isCloudDrive: Bool = false
    public var parent: Project?
    var isDefault: Bool

    public var isVirtual = false
    public var isBookmark: Bool = false

    public var settings: ProjectSettings
    public var metaCache = [NoteMeta]()
    
    // all notes loaded with cache diff comparsion
    public var isReadyForCacheSaving = false

    // if notes loaded from cache validation with fs needed
    public var isNeededCacheValidation = false

    public var child = [Project]()
    public var isExpanded = false
    
    public var isEncrypted = false
    public var password: String?

    public var settingsKey = String()
    public var commitsCache = [String: [String]]()

    public var isCleanGit = false
    public var gitStatus: String?
    public var isActiveGit = false

    init(storage: Storage,
         url: URL,
         label: String? = nil,
         isTrash: Bool = false,
         parent: Project? = nil,
         isDefault: Bool = false,
         isBookmark: Bool = false,
         isVirtual: Bool = false
    ) {
        self.storage = storage
        self.url = url.standardized
        self.isTrash = isTrash
        self.parent = parent
        self.isDefault = isDefault
        self.isBookmark = isBookmark
        self.isVirtual = isVirtual
        self.label = String()

        settings = ProjectSettings()
            
        #if os(iOS)
        if isDefault {
            settings.showInSidebar = false
        }
        #endif

        settingsKey = getSettingsKey()
        
        loadLabel(label)
        isCloudDrive = isCloudDriveFolder(url: url)
        
        // Init sort for default project
        if self.label == "Welcome" {
            settings.sortBy = .title
            settings.sortDirection = .asc
        }
        
        if let settings = getSettings() {
            self.settings = settings
        }
        
        if isTrash {
            settings.showInCommon = false
        }
        
        // Backward compatibility
        if settings.gitOrigin == nil, self.isDefault, let origin = UserDefaultsManagement.gitOrigin {
            settings.setOrigin(origin)
        }
    }
    
    public func getLongSettingsKey() -> String {
        return "es.fsnot.project-settings\(settingsKey)"
    }
    
    public func saveSettings() {
        do {
            NSKeyedArchiver.setClassName("ProjectSettings", for: ProjectSettings.self)
            let data = try NSKeyedArchiver.archivedData(withRootObject: settings, requiringSecureCoding: true)
            let key = getLongSettingsKey()
            
            #if CLOUD_RELATED_BLOCK
                let keyStore = NSUbiquitousKeyValueStore()
                keyStore.set(data, forKey: key)
                keyStore.synchronize()
            #else
                if let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    let url = documentDir.appendingPathComponent(key)
                    try? data.write(to: url)
                }
            #endif
        } catch {
            print("Settings arc error: \(error.localizedDescription)")
        }
    }
        
    public func getSettings() -> ProjectSettings? {
        let key = getLongSettingsKey()
        var data: Data?
                
        #if CLOUD_RELATED_BLOCK
            let keyStore = NSUbiquitousKeyValueStore()
            data = keyStore.data(forKey: key)
        #else
            if let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let url = documentDir.appendingPathComponent(key)
                data = try? Data(contentsOf: url)
            }
        #endif
        
        NSKeyedUnarchiver.setClass(ProjectSettings.self, forClassName: "ProjectSettings")
        if let data = data, let settings = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ProjectSettings.self, from: data) {
            return settings
        }
        
        return nil
    }
    
    public func reloadSettings() {
        if let settings = getSettings() {
            self.settings = settings
        }
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

        var notes = storage.noteList.filter({ $0.project == self })

        for note in notes {
            if note.isEncrypted() {
                _ = note.lock()
            }
        }
        
        // Deduplicate
        let deduplicatedNotes = notes.reduce(into: [String: Note]()) { result, object in
            result[object.url.path] = object
        }.values
        
        notes = Array(deduplicatedNotes)

        let meta = notes.filter({ $0.isValidForCaching() }).map({ $0.getMeta() })
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

            // print("From cache: \(notes.count)")
            
            isNeededCacheValidation = true
        } else {
            notes = fetchNotes()
            for newNote in notes {
                newNote.load()
            }

            // print("From disk: \(notes.count)")
        }

    #if CLOUD_RELATED_BLOCK
        notes = loadPins(for: notes)
    #endif
        
        storage.noteList.append(contentsOf: notes)
    }

    public func fetchAllDocuments(at url: URL) -> [(URL, Date, Date)] {
        let url = url.standardized

        var directoryFiles = [URL]()
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) {
            while let file = enumerator.nextObject() as? URL {
                if storage.isValidNote(url: file) {
                    directoryFiles.append(file)
                }
            }
        }

        let results = directoryFiles.map {
            url in (
                url,
                (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    )?.contentModificationDate ?? Date.distantPast,
                (try? url.resourceValues(forKeys: [.creationDateKey])
                    )?.creationDate ?? Date.distantPast
            )
        }

        return results.map {
            if $0.0.pathExtension == "textbundle" {
                return (
                    URL(fileURLWithPath: $0.0.path, isDirectory: false),
                    $0.1,
                    $0.2
                )
            }

            return $0
        }
    }

    public func loadPins(for notes: [Note]) -> [Note] {
        #if CLOUD_RELATED_BLOCK
        let keyStore = NSUbiquitousKeyValueStore()
        keyStore.synchronize()

        if let names = keyStore.array(forKey: "co.fluder.fsnotes.pins.shared") as? [String] {
            for name in names {
                if let note = notes.first(where: { $0.name == name }) {
                    note.isPinned = true
                }
            }
        }
        #endif

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
        if isDefault || isBookmark {
            return self
        }
        
        if let parent = self.parent {
            return parent.getParent()
        }
        
        return self
    }
    
    public func isVisibleInCommon() -> Bool {
        if !settings.showInCommon {
            return false
        }
        
        var parent = self.parent
                
        while parent != nil {
            if let unwrapped = parent?.parent {
                if !unwrapped.settings.showInCommon {
                    return false
                }
                
                parent = unwrapped
                continue
            }
            
            return parent?.settings.showInCommon == true
        }
        
        return settings.showInCommon
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
        if isDefault || isBookmark {
            if isBookmark {
                return "External › " + label
            }
            
            return label
        }

        if isTrash {
            return "Trash"
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
    
    public func getChildProjects() -> [Project]? {
        var projects = [Project]()

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
    
    public func getChildProjectsByURL() -> [Project] {
        return storage
            .projects
            .filter({ $0.url.path.startsWith(string: url.path) && $0.url.path != url.path })
            .sorted(by: {
                $0.url.path.components(separatedBy: "/").count < $1.url.path.components(separatedBy: "/").count
            })
    }

    public func getHistoryURL() -> URL? {
        let url = storage.getRevisionsHistoryDocumentsSupport()

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

    public func unlock(password: String) -> ([Note], [Note]) {
        let notes = self.storage.getNotesBy(project: self)
        var unlocked = [Note]()

        if notes.count == 0 {
            self.password = password
            return (notes, unlocked)
        }

        for note in notes {
            if note.unLock(password: password) {
                self.password = password
                unlocked.append(note)
            }
        }

        return (notes, unlocked)
    }

    public func lock() -> [Note] {
        var locked = [Note]()
        let notes = self.storage.getNotesBy(project: self)

        for note in notes {
            if note.lock() {
                locked.append(note)
            }
        }

        if locked.count > 0 {
            password = nil
        }

        return locked
    }
    
    public func checkNotesCacheDiff(isGit: Bool = false) -> ([Note], [Note], [Note]) {
        // if not cached – load all results for cache
        // (not loaded instantly because is resource consumption operation, loaded later in background)
        guard isNeededCacheValidation || isGit else {

            _ = storage.noteList
                .filter({ $0.project == self })
                .map({ $0.load() })

            isReadyForCacheSaving = true
            return ([], [], [])
        }


        let results = checkFSAndMemoryDiff()
        
        if results.1.count > 0 {
            print(results)
        }

        print("Cache diff found: removed - \(results.0.count), added - \(results.1.count), modified - \(results.2.count).")
        
        return results
    }
    
    public func getProjectsFSAndMemoryDiff() -> ([Project], [Project]) {
        var foundRemoved = [Project]()
        var foundAdded = [Project]()

        var memoryProjects = [Project]()
        var fileSystemURLs = [URL]()
        
        if let child = getChildProjects() {
            memoryProjects = child
        }
        
        if let fsURLs = fetchAllDirectories() {
            fileSystemURLs = fsURLs
        }

        let cachedProjects = Set(memoryProjects.compactMap({ $0.url }))
        let currentProjects = Set(fileSystemURLs)

        let removed = cachedProjects.subtracting(currentProjects)
        let added = currentProjects.subtracting(cachedProjects)

        for removeURL in removed {
            if let project = memoryProjects.first(where: { $0.url == removeURL }) {
                foundRemoved.append(project)
            }
        }

        for addURL in added {
            let project = Project(storage: storage, url: addURL)
            foundAdded.append(project)
        }
        
        foundAdded = foundAdded.sorted(by: {
            $0.url.path.components(separatedBy: "/").count < $1.url.path.components(separatedBy: "/").count
        })
                
        foundRemoved = foundRemoved.sorted(by: {
            $0.url.path.components(separatedBy: "/").count > $1.url.path.components(separatedBy: "/").count
        })
                        
        return (foundRemoved, foundAdded)
    }
    
    private func fetchAllDirectories() -> [URL]? {
        guard let fileEnumerator =
            FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: nil,
                options: FileManager.DirectoryEnumerationOptions()
            )
        else { return nil }

        let extensions = ["md", "markdown", "txt", "rtf", "fountain", "textbundle", "etp", "jpg", "png", "gif", "jpeg", "json", "JPG", "PNG", ".icloud", ".cache", ".Trash", "i"]

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
                && !$0.path.contains("/.")
                && $0 != UserDefaultsManagement.trashURL
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
                    isPackageResourceValue as? Bool == false,
                    url.isHidden() == false {
                    
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
    
    public func loadNotesContent() {
        let notes = getNotes()
        for note in notes {
            note.load()
        }
    }

    public func getNestedPath() -> String {
        var project: Project? = self
        var result = String()

        while project != nil {
            if project?.parent == nil {
                return result
            }

            if let unwrappedProject = project {
                if result.count > 0 {
                    result = unwrappedProject.label + "/" + result
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
}
