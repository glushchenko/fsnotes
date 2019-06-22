//
//  NoteMO+CoreDataClass.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/24/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//
//

import Foundation
import RNCryptor
import SSZipArchive
import LocalAuthentication

public class Note: NSObject  {
    @objc var title: String = ""
    var project: Project
    var container: NoteContainer = .none
    var type: NoteType = .Markdown
    var url: URL

    var content: NSMutableAttributedString = NSMutableAttributedString()
    var creationDate: Date? = Date()
    var isCached = false
    var sharedStorage = Storage.sharedInstance()
    var tagNames = [String]()
    let dateFormatter = DateFormatter()
    let undoManager = UndoManager()

    public var originalExtension: String?
    
    public var name: String = ""
    public var preview: String = ""
    public var firstLineTitle: String?

    public var isPinned: Bool = false
    public var modifiedLocalAt = Date()

    public var imageUrl: [URL]?
    public var isParsed = false
    private var caching = false

    private var decryptedTemporarySrc: URL?
    public var ciphertextWriter = OperationQueue.init()
    
    // Load exist
    
    init(url: URL, with project: Project) {
        self.ciphertextWriter.maxConcurrentOperationCount = 1
        self.ciphertextWriter.qualityOfService = .userInteractive

        self.url = url
        self.project = project
        super.init()

        self.parseURL(loadProject: false)
    }
    
    // Make new
    
    init(name: String? = nil, project: Project? = nil, type: NoteType? = nil, cont: NoteContainer? = nil) {
        self.ciphertextWriter.maxConcurrentOperationCount = 1
        self.ciphertextWriter.qualityOfService = .userInteractive

        let project = project ?? Storage.sharedInstance().getMainProject()
        let name = name ?? String()

        self.project = project
        self.name = name
        
        self.container = cont ?? UserDefaultsManagement.fileContainer
        self.type = type ?? UserDefaultsManagement.fileFormat
        
        let ext = container == .none
            ? self.type.getExtension(for: container)
            : "textbundle"
                
        url = NameHelper.getUniqueFileName(name: name, project: project, ext: ext)

        super.init()
        self.parseURL()
    }

    /// Important for decrypted temporary containers
    public func getURL() -> URL {
        if let url = self.decryptedTemporarySrc {
            return url
        }

        return self.url
    }
    
    public func loadProject(url: URL) {
        self.url = url
        
        if let project = sharedStorage.getProjectBy(url: url) {
            self.project = project
        }
    }
        
    func load(tags: Bool = true) {        
        if let attributedString = getContent() {
            content = NSMutableAttributedString(attributedString: attributedString)
        }
        
        if !isTrash() && !project.isArchive {
            loadTags()
        }
    }
        
    func reload() -> Bool {
        guard let modifiedAt = getFileModifiedDate() else {
            return false
        }
                        
        if (modifiedAt != modifiedLocalAt) {
            if container != .encryptedTextPack, let attributedString = getContent() {
                content = NSMutableAttributedString(attributedString: attributedString)
            }
            loadModifiedLocalAt()
            return true
        }
        
        return false
    }

    public func forceReload() {
        if container != .encryptedTextPack, let attributedString = getContent() {

            self.content = NSMutableAttributedString(attributedString: attributedString)
        }
    }
    
    func loadModifiedLocalAt() {
        guard let modifiedAt = getFileModifiedDate() else {
            modifiedLocalAt = Date()
            return
        }

        modifiedLocalAt = modifiedAt
    }
    
    public func isTextBundle() -> Bool {
        return (container == .textBundle || container == .textBundleV2)
    }

    public func isFullLoadedTextBundle() -> Bool {
        let ext = getExtensionForContainer()
        let path = url.appendingPathComponent("text.\(ext)").path

        return FileManager.default.fileExists(atPath: path)
    }
    
    public func getExtensionForContainer() -> String {
        return type.getExtension(for: container)
    }
    
    public func getFileModifiedDate() -> Date? {
        do {
            let url = getURL()
            var path = url.path

            if isTextBundle() {
                let ext = getExtensionForContainer()
                path = url.appendingPathComponent("text.\(ext)").path
            }

            let attr = try FileManager.default.attributesOfItem(atPath: path)

            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            NSLog("Note modification date load error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func move(to: URL, project: Project? = nil) -> Bool {
        do {
            var destination = to

            if FileManager.default.fileExists(atPath: to.path) {
                guard let project = project ?? sharedStorage.getProjectBy(url: to) else { return false }

                let ext = getExtensionForContainer()
                destination = NameHelper.getUniqueFileName(name: title, project: project, ext: ext)
            }

            try FileManager.default.moveItem(at: url, to: destination)
            removeCacheForPreviewImages()

            #if os(OSX)
                overwrite(url: destination)
            #endif

            NSLog("File moved from \"\(url.deletingPathExtension().lastPathComponent)\" to \"\(destination.deletingPathExtension().lastPathComponent)\"")
        } catch {
            Swift.print(error)
            return false
        }

        return true
    }
    
    func getNewURL(name: String) -> URL {
        let escapedName = name
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: ":")
        
        var newUrl = url.deletingLastPathComponent()
        newUrl.appendPathComponent(escapedName + "." + url.pathExtension)
        return newUrl
    }

    public func remove() {
        if !isTrash() {
            if let trashURLs = removeFile() {
                self.url = trashURLs[0]
                parseURL()
            }
        } else {
            _ = removeFile()

            if self.isPinned {
                removePin()
            }
        }
    }

    #if os(iOS)
    // Return URL moved in
    func removeFile(completely: Bool = false) -> Array<URL>? {
        if FileManager.default.fileExists(atPath: url.path) {
            if isTrash() || completely {
                try? FileManager.default.removeItem(at: url)
                return nil
            }

            guard let trashUrl = getDefaultTrashURL() else {
                print("Trash not found")

                var resultingItemUrl: NSURL?
                if #available(iOS 11.0, *) {
                    try? FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemUrl)

                    if let result = resultingItemUrl, let path = result.path {
                        return [URL(fileURLWithPath: path), url]
                    }
                }

                return nil
            }

            var trashUrlTo = trashUrl.appendingPathComponent(name)

            if FileManager.default.fileExists(atPath: trashUrlTo.path) {
                let reserveName = "\(Int(Date().timeIntervalSince1970)) \(name)"
                trashUrlTo = trashUrl.appendingPathComponent(reserveName)
            }

            print("Note moved in custom Trash folder")
            try? FileManager.default.moveItem(at: url, to: trashUrlTo)

            return [trashUrlTo, url]
        }
        
        return nil
    }
    #endif

    #if os(OSX)
    func removeFile(completely: Bool = false) -> Array<URL>? {
        if FileManager.default.fileExists(atPath: url.path) {
            if isTrash() {
                try? FileManager.default.removeItem(at: url)
                return nil
            }

            var resultingItemUrl: NSURL?

            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemUrl)

                if let dst = resultingItemUrl, let path = dst.path {

                    let originalURL = url
                    let destination = URL(fileURLWithPath: path)

                    overwrite(url: destination)

                    NSLog("Note moved to trash: \(name)")

                    return [self.url, originalURL]
                }
            } catch {
                return nil
            }
        }

        return nil
    }
    #endif
    
    private func getTrashURL() -> URL? {
        if let url = sharedStorage.getTrash(url: url) {
            return url
        }
        
        return nil
    }

    private func getDefaultTrashURL() -> URL? {
        if let url = sharedStorage.getDefaultTrash()?.url {
            return url
        }

        return nil
    }
        
    public func getPreviewLabel(with text: String? = nil) -> String {
        var preview: String = ""
        let content = text ?? self.content.string
        let length = text?.count ?? self.content.string.count

        if length > 250 {
            if text == nil {
                let startIndex = content.index((content.startIndex), offsetBy: 0)
                let endIndex = content.index((content.startIndex), offsetBy: 250)
                preview = String(content[startIndex...endIndex])
            } else {
                preview = String(content.prefix(250))
            }
        } else {
            preview = content
        }
        
        preview = preview.replacingOccurrences(of: "\n", with: " ")
        if (
            UserDefaultsManagement.horizontalOrientation
                && content.hasPrefix(" – ") == false
            ) {
            preview = " – " + preview
        }
        
        return preview.condenseWhitespace()
    }

    @objc public func getPreviewForLabel() -> String {
        if project.firstLineAsTitle {
            return preview
        }

        return getPreviewLabel()
    }
    
    @objc func getDateForLabel() -> String {
        guard !UserDefaultsManagement.hideDate else { return String() }

        guard let date = (project.sortBy == .creationDate || UserDefaultsManagement.sort == .creationDate)
            ? creationDate
            : modifiedLocalAt
        else { return String() }

        let calendar = NSCalendar.current
        if calendar.isDateInToday(date) {
            return dateFormatter.formatTimeForDisplay(date)
        }
        else {
            return dateFormatter.formatDateForDisplay(date)
        }
    }

    @objc func getCreationDateForLabel() -> String? {
        guard let creationDate = self.creationDate else { return nil }
        guard !UserDefaultsManagement.hideDate else { return nil }

        let calendar = NSCalendar.current
        if calendar.isDateInToday(creationDate) {
            return dateFormatter.formatTimeForDisplay(creationDate)
        }
        else {
            return dateFormatter.formatDateForDisplay(creationDate)
        }
    }
    
    func getContent() -> NSAttributedString? {
        guard container != .encryptedTextPack else { return nil }

        let options = getDocOptions()
        var url = getURL()

        if isTextBundle() {
            let ext = getExtensionForContainer()
            url.appendPathComponent("text.\(ext)")
        }

        do {
            return try NSAttributedString(url: url, options: options, documentAttributes: nil)
        } catch {

            if let data = try? Data(contentsOf: url) {
            let encoding = NSString.stringEncoding(for: data, encodingOptions: nil, convertedString: nil, usedLossyConversion: nil)

                let options = getDocOptions(with: String.Encoding.init(rawValue: encoding))
                return try? NSAttributedString(url: url, options: options, documentAttributes: nil)
            }
        }
        
        return nil
    }
    
    func readModificatonDate() -> Date? {
        var modifiedLocalAt: Date?
        
        do {
            let fileAttribute: [FileAttributeKey : Any] = try FileManager.default.attributesOfItem(atPath: url.path)
            
            modifiedLocalAt = fileAttribute[FileAttributeKey.modificationDate] as? Date
        } catch {
            NSLog(error.localizedDescription)
        }
        
        return modifiedLocalAt
    }
    
    func isRTF() -> Bool {
        return type == .RichText
    }
    
    func isMarkdown() -> Bool {
        return type == .Markdown
    }
    
    func addPin(cloudSave: Bool = true) {
        sharedStorage.pinned += 1
        isPinned = true
        
        #if CLOUDKIT || os(iOS)
        if cloudSave {
            sharedStorage.saveCloudPins()
        }
        #elseif os(OSX)
            var pin = true
            let data = Data(bytes: &pin, count: 1)
            try? url.setExtendedAttribute(data: data, forName: "co.fluder.fsnotes.pin")
        #endif
    }
    
    func removePin(cloudSave: Bool = true) {
        if isPinned {
            sharedStorage.pinned -= 1
            isPinned = false
            
            #if CLOUDKIT || os(iOS)
            if cloudSave {
                sharedStorage.saveCloudPins()
            }
            #elseif os(OSX)
                var pin = false
                let data = Data(bytes: &pin, count: 1)
                try? url.setExtendedAttribute(data: data, forName: "co.fluder.fsnotes.pin")
            #endif
        }
    }
    
    func togglePin() {
        if !isPinned {
            addPin()
        } else {
            removePin()
        }
    }
    
    func cleanMetaData(content: String) -> String {
        var extractedTitle: String = ""
        
        if (content.hasPrefix("---\n")) {
            var list = content.components(separatedBy: "---")
            
            if (list.count > 2) {
                let headerList = list[1].components(separatedBy: "\n")
                for header in headerList {
                    let nsHeader = header as NSString
                    let regex = try! NSRegularExpression(pattern: "title: \"(.*?)\"", options: [])
                    let matches = regex.matches(in: String(nsHeader), options: [], range: NSMakeRange(0, (nsHeader as String).count))
                    
                    if let match = matches.first {
                        let range = match.range(at: 1)
                        extractedTitle = nsHeader.substring(with: range)
                        break
                    }
                }
                
                if (extractedTitle.count > 0) {
                    list.removeSubrange(Range(0...1))
                    
                    return "## " + extractedTitle + "\n\n" + list.joined()
                }
                
                return list.joined()
            }
        }
        
        return content
    }
    
    func getPrettifiedContent() -> String {
        var content = self.content.string

        #if NOT_EXTENSION || os(OSX)
        content = NotesTextProcessor.convertAppLinks(in: content)
        #endif
        
        return cleanMetaData(content: content)
    }

    public func overwrite(url: URL) {
        self.url = url

        parseURL()
    }

    func parseURL(loadProject: Bool = true) {
        if (url.pathComponents.count > 0) {
            container = .withExt(rawValue: url.pathExtension)
            name = url.pathComponents.last!
            
            if isTextBundle() {
                let info = url.appendingPathComponent("info.json")
                
                if let jsonData = try? Data(contentsOf: info),
                    let info = try? JSONDecoder().decode(TextBundleInfo.self, from: jsonData) {
                    
                    if info.version == 0x02 {
                        type = NoteType.withUTI(rawValue: info.type)
                        container = .textBundleV2
                        originalExtension = info.flatExtension
                    } else {
                        type = .Markdown
                        container = .textBundle
                    }
                }
            }
            
            if container == .none {
                type = .withExt(rawValue: url.pathExtension)
            }
            
            loadTitle()
        }

        if loadProject {
            self.loadProject(url: url)
        }
    }

    private func loadTitle() {
        title = url
            .deletingPathExtension()
            .pathComponents
            .last!
            .replacingOccurrences(of: ":", with: "/")
    }
        
    public func save(globalStorage: Bool = true) {
        if self.isMarkdown() {
            self.content = self.content.unLoadCheckboxes()
            
            if UserDefaultsManagement.liveImagesPreview {
                self.content = self.content.unLoadImages(note: self)
            }
        }
        
        self.save(attributedString: self.content, globalStorage: globalStorage)
    }

    private func save(attributedString: NSAttributedString, globalStorage: Bool = true) {
        let url = getURL()
        let attributes = getFileAttributes()
        
        do {
            let fileWrapper = getFileWrapper(attributedString: attributedString)

            if isTextBundle() {
                if !FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)

                    self.writeTextBundleInfo(url: url)
                }
            }

            let contentSrc = getContentFileURL()
            try fileWrapper.write(to: contentSrc, options: .atomic, originalContentsURL: nil)
            try FileManager.default.setAttributes(attributes, ofItemAtPath: contentSrc.path)

            if decryptedTemporarySrc != nil {
                self.ciphertextWriter.cancelAllOperations()
                self.ciphertextWriter.addOperation {
                    usleep(useconds_t(1000000))

                    guard self.ciphertextWriter.operationCount == 1 else { return }
                    self.writeEncrypted()
                }
            }
        } catch {
            NSLog("Write error \(error)")
            return
        }

        if globalStorage {
            sharedStorage.add(self)
        }
    }

    private func getContentFileURL() -> URL {
        let url = getURL()

        if isTextBundle() {
            let ext = getExtensionForContainer()
            return url.appendingPathComponent("text.\(ext)")
        }

        return url
    }

    public func getFileWrapper(with imagesWrapper: FileWrapper? = nil) -> FileWrapper {
        let fileWrapper = getFileWrapper(attributedString: content)

        if isTextBundle() {
            let fileWrapper = getFileWrapper(attributedString: content)
            let info = getTextBundleJsonInfo()
            let infoWrapper = self.getFileWrapper(attributedString: NSAttributedString(string: info))

            let ext = getExtensionForContainer()
            let textBundle = FileWrapper.init(directoryWithFileWrappers: [
                "text.\(ext)": fileWrapper,
                "info.json": infoWrapper
            ])

            let assetsWrapper = imagesWrapper ?? getAssetsFileWrapper()
            textBundle.addFileWrapper(assetsWrapper)

            return textBundle
        }

        fileWrapper.filename = name

        return fileWrapper
    }
    
    private func getTextBundleJsonInfo() -> String {
        if let originalExtension = originalExtension {
            return """
            {
                "transient" : true,
                "type" : "\(type.uti)",
                "creatorIdentifier" : "co.fluder.fsnotes",
                "version" : 2,
                "flatExtension" : "\(originalExtension)"
            }
            """
        }

        return """
        {
            "transient" : true,
            "type" : "\(type.uti)",
            "creatorIdentifier" : "co.fluder.fsnotes",
            "version" : 2
        }
        """
    }

    private func getAssetsFileWrapper() -> FileWrapper {
        let wrapper = FileWrapper.init(directoryWithFileWrappers: [:])
        wrapper.preferredFilename = "assets"

        let assets = url.appendingPathComponent("assets")

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: assets.path)
            for file in files {
                let fileData = try Data(contentsOf: assets.appendingPathComponent(file))
                wrapper.addRegularFile(withContents: fileData, preferredFilename: file)
            }
        } catch {
            print(error)
        }

        return wrapper
    }
    
    private func writeTextBundleInfo(url: URL) {
        let url = url.appendingPathComponent("info.json")
        let info = getTextBundleJsonInfo()

        try? info.write(to: url, atomically: true, encoding: String.Encoding.utf8)
    }
        
    func getFileAttributes() -> [FileAttributeKey: Any] {
        var attributes: [FileAttributeKey: Any] = [:]
        
        modifiedLocalAt = Date()
        
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {}

        attributes[.modificationDate] = modifiedLocalAt
        return attributes
    }
    
    func getFileWrapper(attributedString: NSAttributedString) -> FileWrapper {
        do {
            let range = NSRange(location: 0, length: attributedString.length)
            let documentAttributes = getDocAttributes()
            return try attributedString.fileWrapper(from: range, documentAttributes: documentAttributes)
        } catch {
            return FileWrapper()
        }
    }
        
    func getTitleWithoutLabel() -> String {
        let title = url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")

        if title.isValidUUID {
            return "Untitled Note"
        }

        return title
    }
    
    func markdownCache() {
        guard isMarkdown() && !self.caching && !self.isCached else { return }

        self.caching = true

        #if NOT_EXTENSION || os(OSX)
        NotesTextProcessor.fullScan(note: self)
        #endif

        self.caching = false
        self.isCached = true
    }

    public func reCache() {
        self.isCached = false

        markdownCache()
    }
    
    func getDocOptions(with encoding: String.Encoding = .utf8) -> [NSAttributedString.DocumentReadingOptionKey: Any]  {
        if type == .RichText {
            return [.documentType : NSAttributedString.DocumentType.rtf]
        }
        
        return [
            .documentType : NSAttributedString.DocumentType.plain,
            .characterEncoding : NSNumber(value: encoding.rawValue)
        ]
    }
    
    func getDocAttributes() -> [NSAttributedString.DocumentAttributeKey : Any] {
        var options: [NSAttributedString.DocumentAttributeKey : Any]
    
        if (type == .RichText) {
            options = [
                .documentType : NSAttributedString.DocumentType.rtf

            ]
        } else {
            options = [
                .documentType : NSAttributedString.DocumentType.plain,
                .characterEncoding : NSNumber(value: String.Encoding.utf8.rawValue)
            ]
        }
    
        return options
    }
    
    func isTrash() -> Bool {
        return project.isTrash
    }
    
    public func isInArchive() -> Bool {
        guard UserDefaultsManagement.archiveDirectory != nil else {
            return false
        }
        
        return project.isArchive
    }

    public func contains<S: StringProtocol>(terms: [S]) -> Bool {
        return name.localizedStandardContains(terms) || content.string.localizedStandardContains(terms)
    }

    public func getCommaSeparatedTags() -> String {
        return tagNames.map { String($0) }.joined(separator: ", ")
    }

    public func saveTags(_ string: [String]) -> ([String], [String]) {
        let newTagsClean = string
        var new = [String]()
        var removed = [String]()
        
        for tag in tagNames {
            if !newTagsClean.contains(tag) {
                removed.append(tag)
            }
        }
        
        for newTagClean in newTagsClean {
            if !tagNames.contains(newTagClean) {
                new.append(newTagClean)
            }
        }
        
        for n in new { sharedStorage.addTag(n) }
        
        var removedFromStorage = [String]()
        for r in removed {
            if sharedStorage.removeTag(r) {
                removedFromStorage.append(r)
            }
        }
        
        tagNames = newTagsClean

        #if os(OSX)
            try? (url as NSURL).setResourceValue(newTagsClean, forKey: .tagNamesKey)
        #else
            let data = NSKeyedArchiver.archivedData(withRootObject: NSMutableArray(array: newTagsClean))
            do {
                try self.url.setExtendedAttribute(data: data, forName: "com.apple.metadata:_kMDItemUserTags")
            } catch {
                print(error)
            }
        #endif
        
        return (removedFromStorage, removed)
    }
    
    public func removeAllTags() -> [String] {
        let result = saveTags([])
        
        return result.0
    }
    
    public func addTag(_ name: String) {
        guard !tagNames.contains(name) else { return }
        
        tagNames.append(name)

        #if os(OSX)
            try? (url as NSURL).setResourceValue(tagNames, forKey: .tagNamesKey)
        #else
        let data = NSKeyedArchiver.archivedData(withRootObject: NSMutableArray(array: self.tagNames))
            do {
                try url.setExtendedAttribute(data: data, forName: "com.apple.metadata:_kMDItemUserTags")
            } catch {
                print(error)
            }
        #endif
    }

    public func removeTag(_ name: String) {
        guard tagNames.contains(name) else { return }
        
        if let i = tagNames.firstIndex(of: name) {
            tagNames.remove(at: i)
        }
        
        if sharedStorage.noteList.first(where: {$0.tagNames.contains(name)}) == nil {
            if let i = sharedStorage.tagNames.firstIndex(of: name) {
                sharedStorage.tagNames.remove(at: i)
            }
        }
        
        _ = saveTags(tagNames)
    }
    
    public func loadTags() {
        #if os(OSX)
            let tags = try? url.resourceValues(forKeys: [.tagNamesKey])
            if let tagNames = tags?.tagNames {
                for tag in tagNames {
                    if !self.tagNames.contains(tag) {
                        self.tagNames.append(tag)
                    }
                    
                    if !project.isTrash {
                        sharedStorage.addTag(tag)
                    }
                }
            }
        #else
            if let data = try? url.extendedAttribute(forName: "com.apple.metadata:_kMDItemUserTags"),
                let tags = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSMutableArray {
                self.tagNames.removeAll()
                for tag in tags {
                    if let tagName = tag as? String {
                        self.tagNames.append(tagName)

                        if !project.isTrash {
                            sharedStorage.addTag(tagName)
                        }
                    }
                }
            }
        #endif
    }
    
    public func getImageUrl(imageName: String) -> URL? {
        if imageName.starts(with: "http://") || imageName.starts(with: "https://") {
            return URL(string: imageName)
        }
        
        if isTextBundle() {
            return getURL().appendingPathComponent(imageName)
        }
        
        if type == .Markdown {
            return project.url.appendingPathComponent(imageName)
        }
        
        return nil
    }
    
    public func getImageCacheUrl() -> URL? {
        return project.url.appendingPathComponent("/.cache/")
    }

    #if os(OSX)
    public func getAllImages() -> [(url: URL, path: String)] {
        var res = [(url: URL, path: String)]()

        NotesTextProcessor.imageInlineRegex.regularExpression.enumerateMatches(in: content.string, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(0..<content.length), using:
            {(result, flags, stop) -> Void in

                guard let range = result?.range(at: 3), self.content.length >= range.location else { return }

                let imagePath = self.content.attributedSubstring(from: range).string

                if let url = self.getImageUrl(imageName: imagePath), !url.isRemote() {
                    res.append((url: url, path: imagePath))
                }
        })

        return res
    }

    public func duplicate() {
        var url = self.url
        let ext = url.pathExtension
        url.deletePathExtension()

        let name = url.lastPathComponent
        url.deleteLastPathComponent()

        let now = dateFormatter.formatForDuplicate(Date())
        url.appendPathComponent(name + " " + now)
        url.appendPathExtension(ext)

        try? FileManager.default.copyItem(at: self.url, to: url)
    }

    public func getDupeName() -> String? {
        var url = self.url
        url.deletePathExtension()

        let name = url.lastPathComponent
        url.deleteLastPathComponent()

        let now = dateFormatter.formatForDuplicate(Date())
        return name + " " + now
    }
    #endif

    public func getImagePreviewUrl() -> [URL]? {
        if self.isParsed {
            return self.imageUrl
        }

        var i = 0
        var urls: [URL] = []
        var mdImages: [String] = []

        #if NOT_EXTENSION || os(OSX)
        NotesTextProcessor.imageInlineRegex.regularExpression.enumerateMatches(in: content.string, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(0..<content.length), using:
        {(result, flags, stop) -> Void in

            if let range = result?.range(at: 0) {
                mdImages.append(self.content.attributedSubstring(from: range).string)
            }

            guard let range = result?.range(at: 3), self.content.length >= range.location else { return }

            let imagePath = self.content.attributedSubstring(from: range).string

            if let url = self.getImageUrl(imageName: imagePath) {
                if url.isRemote() {
                    urls.append(url)
                    i += 1
                } else if
                    let cleanPath = url.path.removingPercentEncoding,
                    FileManager.default.fileExists(atPath: cleanPath) {
                        urls.append(URL(fileURLWithPath: cleanPath))
                        i += 1
                }
            }

            if mdImages.count == 3 {
                stop.pointee = true
            }
        })
        #endif

        var cleanText = content.string
        for image in mdImages {
            cleanText = cleanText.replacingOccurrences(of: image, with: "")
        }

        cleanText =
            cleanText
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "- [ ]", with: "")
                .replacingOccurrences(of: "- [x]", with: "")

        let components = cleanText.trim().components(separatedBy: "\n").filter({ $0 != "" })

        if let first = components.first {
            self.firstLineTitle = first.trim()
            self.preview = getPreviewLabel(with: components.dropFirst().joined(separator: " "))
        }

        self.imageUrl = urls
        self.isParsed = true

        return urls
    }

    public func invalidateCache() {
        self.imageUrl = nil
        self.isParsed = false
    }

    public func getMdImagePath(name: String) -> String {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let name = encoded ?? name

        if isTextBundle() {
            return "assets/\(name)"
        }

        return "/i/\(name)"
    }

    public func getMdImageURL(name: String) -> URL? {
        let appendingPath = getMdImagePath(name: name)

        return getImageUrl(imageName: appendingPath)
    }

    public func isEqualURL(url: URL) -> Bool {
        return url.path == self.url.path
    }

    public func append(string: NSMutableAttributedString) {
        content.append(string)
    }

    public func append(image data: Data, url: URL? = nil) {
        guard let fileName = ImagesProcessor.writeImage(data: data, url: url, note: self) else { return }

        let path = getMdImagePath(name: fileName)
        var prefix = "\n\n"
        if content.length == 0 {
            prefix = String()
        }

        let markdown = NSMutableAttributedString(string: "\(prefix)![](\(path))")
        append(string: markdown)
    }

    @objc public func getName() -> String {
        if project.firstLineAsTitle, let title = firstLineTitle {
            return title
        }

        if title.isValidUUID {
            return "Untitled Note"
        }

        return title
    }

    public func getCacheForPreviewImage(at url: URL) -> URL? {
        var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
            temporary.appendPathComponent("Preview")

        if let filePath = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {

            return temporary.appendingPathComponent(filePath)
        }

        return nil
    }

    public func removeCacheForPreviewImages() {
        guard let imageURLs = getImagePreviewUrl() else { return }

        for url in imageURLs {
            if let imageURL = getCacheForPreviewImage(at: url) {
                if FileManager.default.fileExists(atPath: imageURL.path) {
                    try? FileManager.default.removeItem(at: imageURL)
                }
            }
        }
    }

    private func convertFlatToTextBundle() -> URL {
        let temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        let temporaryProject = Project(url: temporary)

        let currentName = url.deletingPathExtension().lastPathComponent
        let note = Note(name: currentName, project: temporaryProject, type: type, cont: .textBundleV2)

        note.originalExtension = url.pathExtension
        note.content = content
        note.save(globalStorage: false)

        return note.url
    }

    private func convertTextBundleToFlat(name: String) {
        let textBundleURL = url
        let json = textBundleURL.appendingPathComponent("info.json")

        if let jsonData = try? Data(contentsOf: json),
            let info = try? JSONDecoder().decode(TextBundleInfo.self, from: jsonData) {
            if let flatExtension = info.flatExtension {
                let ext = NoteType.withUTI(rawValue: info.type).getExtension(for: .textBundleV2)
                let fileName = "text.\(ext)"

                let uniqueURL = NameHelper.getUniqueFileName(name: name, project: project, ext: flatExtension)
                let flatURL = url.appendingPathComponent(fileName)

                url = uniqueURL
                type = .withExt(rawValue: flatExtension)
                container = .none

                try? FileManager.default.moveItem(at: flatURL, to: uniqueURL)
                try? FileManager.default.removeItem(at: textBundleURL)
            }
        }
    }

    private func loadTextBundle() -> Bool {
        do {
            let url = getURL()
            let json = url.appendingPathComponent("info.json")
            let jsonData = try Data(contentsOf: json)
            let info = try JSONDecoder().decode(TextBundleInfo.self, from: jsonData)

            type = .withUTI(rawValue: info.type)

            if info.version == 1 {
                container = .textBundle
                return true
            }

            container = .textBundleV2
            return true
        } catch {
            print("Can not load TextBundle: \(error)")
        }

        return false
    }

    private func writeEncrypted() {
        guard let baseTextPack = self.decryptedTemporarySrc else { return }

        let textPackURL = baseTextPack.appendingPathExtension("textpack")

        SSZipArchive.createZipFile(atPath: textPackURL.path, withContentsOfDirectory: baseTextPack.path)

        do {
            let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")
            let password = try item.readPassword()

            let data = try Data(contentsOf: textPackURL)
            let encryptedData = RNCryptor.encrypt(data: data, withPassword: password)

            try encryptedData.write(to: self.url)
            print("FSNotes successfully writed encrypted data for: \(title)")

            try FileManager.default.removeItem(at: textPackURL)
        } catch {
            return
        }
    }

    public func unLock(password: String) -> Bool {
        do {
            let name = url.deletingPathExtension().lastPathComponent
            let data = try Data(contentsOf: url)

            guard let temporary = sharedStorage.makeTempEncryptionDirectory()?.appendingPathComponent(name) else { return false }

            let temporaryTextPack = temporary.appendingPathExtension("textpack")
            let temporaryTextBundle = temporary.appendingPathExtension("textbundle")

            let decryptedData = try RNCryptor.decrypt(data: data, withPassword: password)
            try decryptedData.write(to: temporaryTextPack)

            let successUnZip = SSZipArchive.unzipFile(atPath: temporaryTextPack.path, toDestination: temporaryTextBundle.path)

            try FileManager.default.removeItem(at: temporaryTextPack)
            guard successUnZip else { return false }

            self.decryptedTemporarySrc = temporaryTextBundle

            guard loadTextBundle() else {
                container = .encryptedTextPack
                return false
            }

            load()
            loadTitle()
            
            invalidateCache()
            reCache()

            return true
        } catch {
            print("Decryption error: \(error)")
            return false
        }
    }

    public func unEncrypt(password: String) -> Bool {
        let originalSrc = url

        do {
            let name = url.deletingPathExtension().lastPathComponent
            let data = try Data(contentsOf: url)

            let decryptedData = try RNCryptor.decrypt(data: data, withPassword: password)
            let textPackURL = url.appendingPathExtension("textpack")
            try decryptedData.write(to: textPackURL)

            let newURL = project.url.appendingPathComponent(name).appendingPathExtension("textbundle")
            url = newURL
            container = .textBundleV2

            let successUnZip = SSZipArchive.unzipFile(atPath: textPackURL.path, toDestination: newURL.path)

            guard successUnZip else {
                url = originalSrc
                container = .encryptedTextPack
                return false
            }

            try FileManager.default.removeItem(at: textPackURL)
            try FileManager.default.removeItem(at: originalSrc)

            convertTextBundleToFlat(name: name)
            self.decryptedTemporarySrc = nil

            load()
            reCache()

            return true

        } catch {
            print("Decryption error: \(error)")

            return false
        }
    }

    public func unEncryptUnlocked() -> Bool {
        guard let decSrcUrl = decryptedTemporarySrc else { return false }

        let originalSrc = url

        do {
            let name = url.deletingPathExtension().lastPathComponent
            let newURL = project.url.appendingPathComponent(name).appendingPathExtension("textbundle")

            url = newURL
            container = .textBundleV2

            try FileManager.default.removeItem(at: originalSrc)
            try FileManager.default.moveItem(at: decSrcUrl, to: newURL)

            self.decryptedTemporarySrc = nil
            convertTextBundleToFlat(name: name)

            load()
            reCache()

            return true

        } catch {
            print("Encryption removing error: \(error)")

            return false
        }
    }

    public func encrypt(password: String) -> Bool {
        var temporaryFlatSrc: URL?
        let isContainer = isTextBundle()

        if !isContainer {
            temporaryFlatSrc = convertFlatToTextBundle()
        }

        let originalSrc = url
        let fileName = url.deletingPathExtension().lastPathComponent

        let baseTextPack = temporaryFlatSrc ?? url
        let textPackURL = baseTextPack.appendingPathExtension("textpack")

        SSZipArchive.createZipFile(atPath: textPackURL.path, withContentsOfDirectory: baseTextPack.path)

        do {
            if let tempURL = temporaryFlatSrc {
                try FileManager.default.removeItem(at: tempURL)
            }

            let data = try Data(contentsOf: textPackURL)
            let encrypted = RNCryptor.encrypt(data: data, withPassword: password)
            let encryptedURL = project.url.appendingPathComponent(fileName).appendingPathExtension("etp")
            
            url = encryptedURL
            container = .encryptedTextPack
            
            try encrypted.write(to: encryptedURL)
            try FileManager.default.removeItem(at: originalSrc)
            try FileManager.default.removeItem(at: textPackURL)

            cleanOut()
            removeTempContainer()

            return true
        } catch {
            print("Encyption error: \(error)")

            return false
        }
    }

    private func cleanOut() {
        imageUrl = nil

        content = NSMutableAttributedString(string: String())
        preview = String()
        title = String()
        firstLineTitle = nil

        isCached = false
        caching = false
    }

    private func removeTempContainer() {
        if let url = decryptedTemporarySrc {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func isUnlocked() -> Bool {
        return (decryptedTemporarySrc != nil)
    }

    public func isEncrypted() -> Bool {
        return (container == .encryptedTextPack || isUnlocked())
    }

    public func lock() -> Bool {
        guard let temporaryURL = self.decryptedTemporarySrc else { return false }

        while true {
            if ciphertextWriter.operationCount == 0 {
                print("Note \"\(title)\" successfully locked.")

                container = .encryptedTextPack
                cleanOut()
                loadTitle()

                try? FileManager.default.removeItem(at: temporaryURL)
                self.decryptedTemporarySrc = nil

                return true
            }

            usleep(100000)
        }
    }

    public func showIconInList() -> Bool {
        return (isPinned || isEncrypted())
    }
    
}
