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

    let dateFormatter = DateFormatter()
    let undoManager = UndoManager()

    public var tags = [String]()
    public var noteDate: Date = Date()
    public var originalExtension: String?

    /*
     Filename with extension ie "example.textbundle"
     */
    public var name = String()

    /*
     Filename "example"
     */
    public var fileName = String()
    public var preview: String = ""

    public var isPinned: Bool = false
    public var modifiedLocalAt = Date()

    public var imageUrl: [URL]?
    public var isParsed = false

    private var decryptedTemporarySrc: URL?

    private var firstLineAsTitle = false
    private var lastSelectedRange: NSRange?

    public var isLoaded = false
    public var isLoadedFromCache = false

    public var password: String?

    public var cachingInProgress: Bool = false
    public var cacheHash: String?
    
    public var uploadPath: String?
    public var apiId: String?
    
    public var previewState: Bool = false

    // Load exist
    
    init(url: URL, with project: Project, modified: Date? = nil, created: Date? = nil) {
        if let modified = modified {
            modifiedLocalAt = modified
        }
        
        if let created = created {
            creationDate = created
        }

        self.url = url.standardized
        self.project = project
        super.init()

        self.parseURL(loadProject: false)
    }
    
    // Make new
    
    init(name: String? = nil, project: Project? = nil, type: NoteType? = nil, cont: NoteContainer? = nil) {
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

    init(meta: NoteMeta, project: Project) {
        isLoadedFromCache = true
        isParsed = true
        
        url = meta.url
        imageUrl = meta.imageUrl
        title = meta.title
        tags = meta.tags
        noteDate = meta.noteDate
        preview = meta.preview
        modifiedLocalAt = meta.modificationDate
        creationDate = meta.creationDate
        isPinned = meta.pinned
        self.project = project

        super.init()

        parseURL(loadProject: false)
    }

    func getMeta() -> NoteMeta {
        return NoteMeta(
            url: url,
            imageUrl: imageUrl,
            title: title,
            tags: tags,
            noteDate: noteDate,
            preview: preview,
            modificationDate: modifiedLocalAt,
            creationDate: creationDate!,
            pinned: isPinned
        )
    }

    public func setLastSelectedRange(value: NSRange)
    {
        lastSelectedRange = value
    }

    public func getLastSelectedRange() -> NSRange? {
        return lastSelectedRange
    }

    public func hasTitle() -> Bool {
        return !firstLineAsTitle
    }

    /// Important for decrypted temporary containers
    public func getURL() -> URL {
        if let url = self.decryptedTemporarySrc {
            return url
        }

        return self.url
    }
    
    public func loadProject() {
        let sharedStorage = Storage.sharedInstance()
        
        if let project = sharedStorage.getProjectByNote(url: url) {
            self.project = project
        }
    }

    public func forceLoad(skipCreateDate: Bool = false) {
        invalidateCache()
        load()

        if !skipCreateDate {
            loadCreationDate()
        }
        
        loadModifiedLocalAt()
    }

    public func setCreationDate(string: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let userDate = formatter.date(from: string)
        let attributes = [FileAttributeKey.creationDate: userDate]

        do {
            try FileManager.default.setAttributes(attributes as [FileAttributeKey : Any], ofItemAtPath: url.path)

            creationDate = userDate
            return true
        } catch {
            print(error)
            return false
        }
    }

    public func setCreationDate(date: Date) -> Bool {
        let attributes = [FileAttributeKey.creationDate: date]

        do {
            try FileManager.default.setAttributes(attributes as [FileAttributeKey : Any], ofItemAtPath: url.path)

            creationDate = date
            return true
        } catch {
            print(error)
            return false
        }
    }

    func fastLoad() {
        if let attributedString = getContent() {
            cacheHash = nil
            content = NSMutableAttributedString(attributedString: attributedString)
        }

        loadFileName()
        isLoaded = true
    }

    func load(tags: Bool = true) {
        if let attributedString = getContent() {
            cacheHash = nil
            content = NSMutableAttributedString(attributedString: attributedString)
        }

        loadFileName()

        #if os(iOS)
            loadPreviewInfo()
        #else
            if !isTrash() && !project.isArchive && tags {
                loadTags()
            }
        #endif

        isLoaded = true
    }

    public func loadFileWithAttributes() {
        load()
        loadFileAttributes()
    }

    public func loadFileAttributes() {
        loadCreationDate()
        loadModifiedLocalAt()
    }

    func reload() -> Bool {
        guard let modifiedAt = getFileModifiedDate() else {
            return false
        }
                        
        if (modifiedAt != modifiedLocalAt) {
            if let attributedString = getContent() {
                cacheHash = nil
                content = NSMutableAttributedString(attributedString: attributedString)
            }
            loadModifiedLocalAt()
            return true
        }
        
        return false
    }

    public func forceReload() {
        if container != .encryptedTextPack, let attributedString = getContent() {
            cacheHash = nil
            content = NSMutableAttributedString(attributedString: attributedString)
        }
    }
    
    public func loadModifiedLocalAt() {
        modifiedLocalAt = getFileModifiedDate() ?? Date.distantPast
    }

    public func loadCreationDate() {
        creationDate = getFileCreationDate() ?? Date.distantPast
    }
    
    public func isTextBundle() -> Bool {
        return (container == .textBundle || container == .textBundleV2)
    }

    public func isFullLoadedTextBundle() -> Bool {
        return getContentFileURL() != nil
    }
    
    public func getExtensionForContainer() -> String {
        return type.getExtension(for: container)
    }

    public func getFileModifiedDate() -> Date? {
        let url = getURL()

        do {
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            
            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            NSLog("Note modification date load error: \(error.localizedDescription)")
        }

        return
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
    }

    public func getFileCreationDate() -> Date? {
        let url = getURL()

        return
            (try? url.resourceValues(forKeys: [.creationDateKey]))?
                .creationDate
    }
    
    func move(to: URL, project: Project? = nil, forceRewrite: Bool = false) -> Bool {
        let sharedStorage = Storage.sharedInstance()

        do {
            var destination = to

            if FileManager.default.fileExists(atPath: to.path) && !forceRewrite {
                guard let project = project ?? sharedStorage.getProjectByNote(url: to) else { return false }

                let ext = url.pathExtension
                destination = NameHelper.getUniqueFileName(name: title, project: project, ext: ext)
            }

            try FileManager.default.moveItem(at: url, to: destination)
            removeCacheForPreviewImages()

            #if os(OSX)
                let restorePin = isPinned
                if isPinned {
                    removePin()
                }

                overwrite(url: destination)

                if restorePin {
                    addPin()
                }
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
        if !isTrash() && !isEmpty() {
            let src = url
            if let trashURLs = removeFile() {
                let dst = trashURLs[0]
                self.url = dst
                parseURL()

                #if os(iOS)
                    moveHistory(src: src, dst: dst)
                #endif
            }
        } else {
            _ = removeFile()

            if self.isPinned {
                removePin()
            }

            #if os(iOS)
                dropRevisions()
            #endif
        }
    }

    public func isEmpty() -> Bool {
        return content.length == 0 && !isEncrypted()
    }

    #if os(iOS)
    // Return URL moved in
    func removeFile(completely: Bool = false) -> Array<URL>? {
        if FileManager.default.fileExists(atPath: url.path) {
            if isTrash() || completely || isEmpty() {
                try? FileManager.default.removeItem(at: url)

                if type == .Markdown && container == .none {
                    let urls = getAllImages()
                    for url in urls {
                        try? FileManager.default.removeItem(at: url.url)
                    }
                }

                return nil
            }

            guard let trashUrl = getDefaultTrashURL() else {
                print("Trash not found")

                var resultingItemUrl: NSURL?
                if #available(iOS 11.0, *) {
                    if let trash = Storage.sharedInstance().getDefaultTrash() {
                        moveImages(to: trash)
                    }

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

            if let trash = Storage.sharedInstance().getDefaultTrash() {
                moveImages(to: trash)
            }
            
            try? FileManager.default.moveItem(at: url, to: trashUrlTo)

            return [trashUrlTo, url]
        }
        
        return nil
    }
    #endif

    #if os(OSX)
    func removeFile(completely: Bool = false) -> Array<URL>? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        if isTrash() || completely {
            try? FileManager.default.removeItem(at: url)

            if type == .Markdown && container == .none {
                let urls = getAllImages()
                for url in urls {
                    try? FileManager.default.removeItem(at: url.url)
                }
            }

            return nil
        }

        do {
            guard let dst = Storage.sharedInstance().trashItem(url: url) else {
                var resultingItemUrl: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemUrl)

                guard let dst = resultingItemUrl else { return nil }

                let originalURL = url

                overwrite(url: dst as URL)

                return [self.url, originalURL]
            }

            if let trash = Storage.sharedInstance().getDefaultTrash() {
                moveImages(to: trash)
            }

            try FileManager.default.moveItem(at: url, to: dst)

            let originalURL = url
            overwrite(url: dst)
            return [self.url, originalURL]

        } catch {
            print("Trash error: \(error)")
        }

        return nil
    }
    #endif

    public func getAttachPrefix(url: URL? = nil) -> String {
        if let url = url, !url.isImage {
            return "files/"
        }

        return "i/"
    }

    public func move(from imageURL: URL, imagePath: String, to project: Project, copy: Bool = false) {
        let dstPrefix = getAttachPrefix(url: imageURL)
        let dest = project.url.appendingPathComponent(dstPrefix, isDirectory: true)

        if !FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: false, attributes: nil)

            if let data = "true".data(using: .utf8) {
                try? dest.setExtendedAttribute(data: data, forName: "es.fsnot.hidden.dir")
            }
        }

        do {
            if copy {
                try FileManager.default.copyItem(at: imageURL, to: dest)
            } else {
                try FileManager.default.moveItem(at: imageURL, to: dest)
            }
        } catch {
            if let fileName = ImagesProcessor.getFileName(from: imageURL, to: dest, ext: imageURL.pathExtension) {
                let dest = dest.appendingPathComponent(fileName)

                if copy {
                    try? FileManager.default.copyItem(at: imageURL, to: dest)
                } else {
                    try? FileManager.default.moveItem(at: imageURL, to: dest)
                }

                let prefix = "]("
                let postfix = ")"
                
                let imagePath = imagePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? imagePath

                let find = prefix + imagePath + postfix
                let replace = prefix + dstPrefix + fileName + postfix

                guard find != replace else { return }

                while content.mutableString.contains(find) {
                    let range = content.mutableString.range(of: find)
                    content.replaceCharacters(in: range, with: replace)
                }
            }
        }
    }

    public func moveImages(to project: Project) {
        if type == .Markdown && container == .none {
            let imagesMeta = getAllImages()
            for imageMeta in imagesMeta {
                let imagePath = project.url.appendingPathComponent(imageMeta.path).path
                project.storage.hideImages(directory: imagePath, srcPath: imagePath)

                // Copy if image used more then one time on project
                let copy = self.project.countNotes(contains: imageMeta.url) > 0
                move(from: imageMeta.url, imagePath: imageMeta.path, to: project, copy: copy)
            }

            if imagesMeta.count > 0 {
                save()
            }
        }
    }
    
    private func getDefaultTrashURL() -> URL? {
        if let url = Storage.sharedInstance().getDefaultTrash()?.url {
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

        preview = preview.condenseWhitespace()

        if preview.starts(with: "![") {
            return ""
        }

        return preview
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
        guard container != .encryptedTextPack, let url = getContentFileURL() else { return nil }

        do {
            let options = getDocOptions()

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

    func getAltContent(url: URL) -> NSAttributedString? {
        guard container != .encryptedTextPack else { return nil }

        do {
            let options = getDocOptions()

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
        
    func isRTF() -> Bool {
        return type == .RichText
    }
    
    func isMarkdown() -> Bool {
        return type == .Markdown
    }
    
    func addPin(cloudSave: Bool = true) {
        isPinned = true
        
    #if CLOUDKIT || os(iOS)
        if cloudSave {
            Storage.sharedInstance().saveCloudPins()
        }
    #elseif os(OSX)
        addLocalPin(url: url)
    #endif

    }

    func removePin(cloudSave: Bool = true) {
        if isPinned {
            isPinned = false
            
            #if CLOUDKIT || os(iOS)
            if cloudSave {
                Storage.sharedInstance().saveCloudPins()
            }
            #elseif os(OSX)
                removeLocalPin(url: url)
            #endif
        }
    }

    public func addLocalPin(url: URL) {
        var pins = UserDefaultsManagement.pinList

        if !pins.contains(url.path) {
            pins.append(url.path)
        }

        UserDefaultsManagement.pinList = pins
    }

    public func removeLocalPin(url: URL) {
        var pins = UserDefaultsManagement.pinList

        if pins.contains(url.path) {
            if let index = pins.firstIndex(of: url.path) {
                pins.remove(at: index)
            }
        }

        UserDefaultsManagement.pinList = pins
    }
    
    func togglePin() {
        if !isPinned {
            addPin()
        } else {
            removePin()
        }
    }
    
    func cleanMetaData(content: String) -> String {
        var extractedTitle = String()
        var author = String()
        var date = String()
        
        if (content.hasPrefix("---\n")) {
            var list = content.components(separatedBy: "---")
            
            if (list.count > 2) {
                let headerList = list[1].components(separatedBy: "\n")
                for header in headerList {
                    if header.hasPrefix("title:") {
                        extractedTitle = header.replacingOccurrences(of: "title:", with: "").trim()
                        
                        if extractedTitle.hasPrefix("\"") && extractedTitle.hasSuffix("\""){
                            extractedTitle = String(extractedTitle.dropFirst(1))
                            extractedTitle = String(extractedTitle.dropLast(1))
                        }
                    }
                    
                    if header.hasPrefix("author:") {
                        author = header.replacingOccurrences(of: "author:", with: "").trim()
                        
                        if author.hasPrefix("\"") && author.hasSuffix("\""){
                            author = String(author.dropFirst(1))
                            author = String(author.dropLast(1))
                        }
                    }
                    
                    if header.hasPrefix("date:") {
                        date = header.replacingOccurrences(of: "date:", with: "").trim()
                        
                        if date.hasPrefix("\"") && date.hasSuffix("\""){
                            date = String(date.dropFirst(1))
                            date = String(date.dropLast(1))
                        }
                    }
                }
                
                list.removeSubrange(Range(0...1))
                
                var result = String()
                
                if (extractedTitle.count > 0) {
                    result = "<h1 class=\"no-border\">" + extractedTitle + "</h1>\n\n"
                }
                
                if (author.count > 0) {
                    result += "_" + author + "_\n\n"
                }
                
                if (date.count > 0) {
                    result += "_" + date + "_\n\n"
                }
                
                if result.count > 0 {
                    result += "<hr>\n\n"
                }
                
                result += list.joined()
                
                return result
            }
        }
        
        return content
    }
    
    func getPrettifiedContent() -> String {
        #if NOT_EXTENSION || os(OSX)
            let mutable = NotesTextProcessor.convertAppTags(in: self.content)
            let content = NotesTextProcessor.convertAppLinks(in: mutable)
            let result = cleanMetaData(content: content.string)
                .replacingOccurrences(of: "\n---\n", with: "\n<hr>\n")
        
            return result
        #else
            return cleanMetaData(content: self.content.string)
        #endif
    }

    public func overwrite(url: URL) {
        self.url = url

        parseURL()
    }

    func parseURL(loadProject: Bool = true) {
        if (url.pathComponents.count > 0) {
            container = .withExt(rawValue: url.pathExtension)
            name = url.lastPathComponent
            
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
            loadFileName()
        }

        if loadProject {
            self.loadProject()
        }
    }

    private func loadTitle() {
        if !(UserDefaultsManagement.firstLineAsTitle || project.firstLineAsTitle) {
            title = url
                .deletingPathExtension()
                .pathComponents
                .last!
                .replacingOccurrences(of: ":", with: "/")
        }
    }

    private func loadFileName() {
        fileName = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: ":", with: "/")
    }

    public func getFileName() -> String {
        return fileName
    }

    public func save(attributed: NSAttributedString) {
        Storage.sharedInstance().plainWriter.cancelAllOperations()
        Storage.sharedInstance().plainWriter.addOperation {
            if let copy = attributed.copy() as? NSAttributedString {
                let mutable = NSMutableAttributedString(attributedString: copy)
                self.save(content: mutable)
                usleep(100000)
            }
        }
    }

    public func saveSync(copy: NSAttributedString) {
        let mutableCopy = NSMutableAttributedString(attributedString: copy)
        let unloadedCopy = mutableCopy.unLoad()

        self.content = unloadedCopy
        self.save(content: unloadedCopy)
    }

    public func save(content: NSMutableAttributedString) {
        if isRTF() {
            #if os(OSX)
                self.content = content.unLoadUnderlines()
            #else
                self.content = content
            #endif
        } else {
            self.content = content.unLoad()
        }

        save(attributedString: self.content)
    }

    public func replace(tag: String, with string: String) {
        if isMarkdown() {
            self.content = content.unLoad()
        }

        content.replaceTag(name: tag, with: string)
        save()
    }

    public func delete(tag: String) {
        if isMarkdown() {
            self.content = content.unLoad()
        }

        content.replaceTag(name: tag, with: "")
        save()
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

            let contentSrc: URL? = getContentFileURL()
            let dst = contentSrc ?? getContentSaveURL()

            var originalContentsURL: URL? = nil
            if let contentSrc = contentSrc {
                originalContentsURL = contentSrc
            }

            try fileWrapper.write(to: dst, options: .atomic, originalContentsURL: originalContentsURL)
            try FileManager.default.setAttributes(attributes, ofItemAtPath: dst.path)

            if decryptedTemporarySrc != nil {
                Storage.sharedInstance().ciphertextWriter.cancelAllOperations()
                Storage.sharedInstance().ciphertextWriter.addOperation {
                    guard Storage.sharedInstance().ciphertextWriter.operationCount == 1 else { return }
                    self.writeEncrypted()
                }
            } else {
                modifiedLocalAt = Date()
            }

        } catch {
            NSLog("Write error \(error)")
            return
        }

        if globalStorage {
            Storage.sharedInstance().add(self)
        }
    }

    private func getContentSaveURL() -> URL {
        let url = getURL()

        if isTextBundle() {
            let ext = getExtensionForContainer()
            return url.appendingPathComponent("text.\(ext)")
        }

        return url
    }

    public func getContentFileURL() -> URL? {
        var url = getURL()

        if isTextBundle() {
            let ext = getExtensionForContainer()
            url = url.appendingPathComponent("text.\(ext)")

            if !FileManager.default.fileExists(atPath: url.path) {
                url = url.deletingLastPathComponent()

                if let dirList = try? FileManager.default.contentsOfDirectory(atPath: url.path),
                    let first = dirList.first(where: { $0.starts(with: "text.") })
                {
                    url = url.appendingPathComponent(first)

                    return url
                }

                return nil
            }

            return url
        }

        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        return nil
    }

    public func getFileWrapper(with imagesWrapper: FileWrapper? = nil) -> FileWrapper {
        let fileWrapper = getFileWrapper(attributedString: content)

        if isTextBundle() {
            let fileWrapper = getFileWrapper(attributedString: content)
            let info = getTextBundleJsonInfo()
            let infoWrapper = self.getFileWrapper(attributedString: NSAttributedString(string: info), forcePlain: true)

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

        do {
            let assets = url.appendingPathComponent("assets")

            var isDir = ObjCBool(false)
            if FileManager.default.fileExists(atPath: assets.path, isDirectory: &isDir) && isDir.boolValue {
                let files = try FileManager.default.contentsOfDirectory(atPath: assets.path)
                for file in files {
                    let fileData = try Data(contentsOf: assets.appendingPathComponent(file))
                    wrapper.addRegularFile(withContents: fileData, preferredFilename: file)
                }
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
    
    func getFileWrapper(attributedString: NSAttributedString, forcePlain: Bool = false) -> FileWrapper {
        do {
            let range = NSRange(location: 0, length: attributedString.length)

            var documentAttributes = getDocAttributes()

            if forcePlain {
                documentAttributes = [
                    .documentType : NSAttributedString.DocumentType.plain,
                    .characterEncoding : NSNumber(value: String.Encoding.utf8.rawValue)
                ]
            }

            return try attributedString.fileWrapper(from: range, documentAttributes: documentAttributes)
        } catch {
            return FileWrapper()
        }
    }
        
    func getTitleWithoutLabel() -> String {
        let title = url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")

        if title.isValidUUID {
            return ""
        }

        return title
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

#if os(OSX)
    public func loadTags() {
        if UserDefaultsManagement.inlineTags {
            _ = scanContentTags()
            return
        }
    }
#else
    public func loadTags() -> Bool {
        _ = Storage.sharedInstance()

        if UserDefaultsManagement.inlineTags {
            let changes = scanContentTags()
            let qty = changes.0.count + changes.1.count

            if (qty > 0) {
                return true
            }
        }

        return false
    }
#endif

    public func scanContentTags() -> ([String], [String]) {
        var added = [String]()
        var removed = [String]()

        let matchingOptions = NSRegularExpression.MatchingOptions(rawValue: 0)
        let options: NSRegularExpression.Options = [
            .allowCommentsAndWhitespace,
            .anchorsMatchLines
        ]

        var tags = [String]()

        do {
            let range = NSRange(location: 0, length: content.length)
            let re = try NSRegularExpression(pattern: FSParser.tagsPattern, options: options)

            re.enumerateMatches(
                in: content.string,
                options: matchingOptions,
                range: range,
                using: { (result, flags, stop) -> Void in

                    guard var range = result?.range(at: 1) else { return }
                    let cleanTag = content.mutableString.substring(with: range)

                    range = NSRange(location: range.location - 1, length: range.length + 1)

                    let codeBlock = FSParser.getFencedCodeBlockRange(paragraphRange: range, string: content)
                    let spanBlock = FSParser.getSpanCodeBlockRange(content: content, range: range)

                    if codeBlock == nil && spanBlock == nil && isValid(tag: cleanTag) {

                        let parRange = content.mutableString.paragraphRange(for: range)
                        let par = content.mutableString.substring(with: parRange)
                        if par.starts(with: "    ") || par.starts(with: "\t") {
                            return
                        }
                        
                        if cleanTag.last == "/" {
                            tags.append(String(cleanTag.dropLast()))
                        } else {
                            tags.append(cleanTag)
                        }
                    }
                }
            )
        } catch {
            print("Tags parsing: \(error)")
        }

        if tags.contains("notags") {
            removed = self.tags

            self.tags.removeAll()
            return (added, removed)
        }

        for noteTag in self.tags {
            if !tags.contains(noteTag) {
                removed.append(noteTag)
            }
        }
        
        for tag in tags {
            if !self.tags.contains(tag) {
                added.append(tag)
            }
        }


        self.tags = tags

        return (added, removed)
    }

    private var excludeRanges = [NSRange]()

    public func isValid(tag: String) -> Bool {
        if tag.isNumber {
            return false
        }

        return true
    }
    
    public func getImageUrl(imageName: String) -> URL? {
        if imageName.starts(with: "http://") || imageName.starts(with: "https://") {
            return URL(string: imageName)
        }

        if isEncrypted() && (
            imageName.starts(with: "/i/") || imageName.starts(with: "i/")
        ) {
            return project.url.appendingPathComponent(imageName)
        }
        
        if isTextBundle() {
            return getURL().appendingPathComponent(imageName)
        }
        
        if type == .Markdown {
            return project.url.appendingPathComponent(imageName)
        }
        
        return nil
    }
    
    public func getAllImages(content: NSMutableAttributedString? = nil) -> [(url: URL, path: String)] {
        let content = content ?? self.content
        var res = [(url: URL, path: String)]()

        FSParser.imageInlineRegex.regularExpression.enumerateMatches(in: content.string, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(0..<content.length), using:
            {(result, flags, stop) -> Void in

            guard let range = result?.range(at: 3), content.length >= range.location else { return }

            let imagePath = content.attributedSubstring(from: range).string.removingPercentEncoding

            if let imagePath = imagePath, let url = self.getImageUrl(imageName: imagePath), !url.isRemote() {
                res.append((url: url, path: imagePath))
            }
        })

        return res
    }

    public func dropImagesCache() {
        let urls = getAllImages()

        for url in urls {
            var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
            temporary.appendPathComponent("ThumbnailsBigInline")

            let cacheUrl = temporary.appendingPathComponent(url.0.absoluteString.md5 + "." + url.0.pathExtension)
            try? FileManager.default.removeItem(at: cacheUrl)
        }
    }

    public func countCheckSum() -> String {
        let urls = getAllImages()
        var size = UInt64(0)

        for url in urls {
            size += url.0.fileSize
        }

        return content.string.md5 + String(size)
    }

    #if os(OSX)
    public func getDupeName() -> String? {
        var url = self.url
        let ext = url.pathExtension
        url.deletePathExtension()

        var name = url.lastPathComponent
        url.deleteLastPathComponent()

        let regex = try? NSRegularExpression(pattern: "(.+)\\sCopy\\s(\\d)+$", options: .caseInsensitive)
        if let result = regex?.firstMatch(in: name, range: NSRange(0..<name.count)) {
            if let range = Range(result.range(at: 1), in: name) {
                name = String(name[range])
            }
        }

        var endName = name
        if !endName.hasSuffix(" Copy") {
            endName += " Copy"
        }

        let dstUrl = NameHelper.getUniqueFileName(name: endName, project: project, ext: ext)

        return dstUrl.deletingPathExtension().lastPathComponent
    }
    #endif

    public func loadPreviewInfo(text: String? = nil) {
        let content = text ?? self.content.string

        if self.isParsed {
            return
        }

        var i = 0
        var urls: [URL] = []
        var mdImages: [String] = []

        FSParser.imageInlineRegex.regularExpression.enumerateMatches(in: content, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(0..<content.count), using:
        {(result, flags, stop) -> Void in

            let nsContent = content as NSString
            if let range = result?.range(at: 0) {
                mdImages.append(nsContent.substring(with: range))
            }

            guard let range = result?.range(at: 3), nsContent.length >= range.location else { return }

            guard let imagePath = nsContent.substring(with: range).removingPercentEncoding else { return }

            if let url = self.getImageUrl(imageName: imagePath) {
                if url.isRemote() {
                    return
                } else if FileManager.default.fileExists(atPath: url.path), url.isImage || url.isVideo {

                    if container == .none && type == .Markdown {
                        var prefix = imagePath
                        if imagePath.first == "/" {
                            prefix = String(imagePath.dropFirst())
                        }
                        let imageURL = project.url.appendingPathComponent(prefix)
                        let mediaPath = imageURL.deletingLastPathComponent().path

                        project.storage.hideImages(directory: mediaPath, srcPath: prefix)
                    }

                    urls.append(url)
                    i += 1
                }
            }

            if mdImages.count > 3 {
                stop.pointee = true
            }
        })

        var cleanText = content
        for image in mdImages {
            cleanText = cleanText.replacingOccurrences(of: image, with: "")
        }

        cleanText =
            cleanText
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "```", with: "")
                .replacingOccurrences(of: "- [ ]", with: "")
                .replacingOccurrences(of: "- [x]", with: "")
                .replacingOccurrences(of: "[[", with: "")
                .replacingOccurrences(of: "]]", with: "")
                .replacingOccurrences(of: "{{TOC}}", with: "")

        let components = cleanText.trim().components(separatedBy: NSCharacterSet.newlines).filter({ $0 != "" })

        if let first = components.first {
            if UserDefaultsManagement.firstLineAsTitle || project.firstLineAsTitle {
                loadYaml(components: components)

                if title.count == 0 {
                    title = first.trim()
                    preview = getPreviewLabel(with: components.dropFirst().joined(separator: " "))
                    firstLineAsTitle = true
                }
            } else {
                loadTitleFromFileName()
                self.preview = getPreviewLabel(with: components.joined(separator: " "))
            }
        } else {
            if !(UserDefaultsManagement.firstLineAsTitle || project.firstLineAsTitle) {
                loadTitleFromFileName()
            } else {
                firstLineAsTitle = false
            }
        }

        self.imageUrl = urls
        self.isParsed = true
    }

    private func loadYaml(components: [String]) {
        var tripleMinus = 0
        var previewFragments = [String]()

        if components.first == "---", components.count > 1 {
            for string in components {
                if string == "---" {
                    tripleMinus += 1
                }

                let res = string.matchingStrings(regex: "^title: ([\"\'”“]?)([^\n]+)\\1$")

                if res.count > 0 {
                    title = res[0][2].trim()
                    firstLineAsTitle = true
                }

                if tripleMinus > 1 {
                    previewFragments.append(string)
                }
            }
        }

        if previewFragments.count > 0 {
            let previewString = previewFragments
                .joined(separator: " ")
                .replacingOccurrences(of: "---", with: "")

            preview = getPreviewLabel(with: previewString)
        }
    }

    private func loadTitleFromFileName() {
        let fileName = url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")

        self.title = fileName

        firstLineAsTitle = false
    }

    public func invalidateCache() {
        self.imageUrl = nil
        self.preview = String()
        self.title = String()
        self.isParsed = false
    }

    public func getMdImagePath(name: String) -> String {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let name = encoded ?? name

        if isTextBundle() {
            return "assets/\(name)"
        }

        return "i/\(name)"
    }

    public func isEqualURL(url: URL) -> Bool {
        return url.path == self.url.path
    }

    public func append(string: NSMutableAttributedString) {
        content.append(string)
    }

    public func append(image data: Data, url: URL? = nil) {
        guard let path = ImagesProcessor.writeFile(data: data, url: url, note: self) else { return }

        var prefix = "\n\n"
        if content.length == 0 {
            prefix = String()
        }

        let markdown = NSMutableAttributedString(string: "\(prefix)![](\(path))")
        append(string: markdown)
    }

    @objc public func getName() -> String {
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
        loadPreviewInfo()

        guard let imageURLs = imageUrl else { return }

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
        let temporaryProject = Project(storage: project.storage, url: temporary)

        let currentName = url.deletingPathExtension().lastPathComponent
        let note = Note(name: currentName, project: temporaryProject, type: type, cont: .textBundleV2)

        note.originalExtension = url.pathExtension
        note.content = content
        note.save(globalStorage: false)

        if type == .Markdown {
            let imagesMeta = getAllImages()
            for imageMeta in imagesMeta {
                moveFilesFlatToAssets(note: note, from: imageMeta.url, imagePath: imageMeta.path, to: note.url)
            }

            note.save(globalStorage: false)
        }

        return note.url
    }

    private func convertTextBundleToFlat(name: String) {
        let textBundleURL = url
        let json = textBundleURL.appendingPathComponent("info.json")

        if let jsonData = try? Data(contentsOf: json),
            let info = try? JSONDecoder().decode(TextBundleInfo.self, from: jsonData) {
                        
            let ext = NoteType.withUTI(rawValue: info.type).getExtension(for: .textBundleV2)
            let flatExtension = info.flatExtension ?? ext
            
            let fileName = "text.\(ext)"

            let uniqueURL = NameHelper.getUniqueFileName(name: name, project: project, ext: flatExtension)
            let flatURL = url.appendingPathComponent(fileName)

            url = uniqueURL
            type = .withExt(rawValue: flatExtension)
            container = .none

            try? FileManager.default.moveItem(at: flatURL, to: uniqueURL)

            moveFilesAssetsToFlat(content: uniqueURL, src: textBundleURL, project: project)

            try? FileManager.default.removeItem(at: textBundleURL)
        }
    }

    private func moveFilesFlatToAssets(note: Note, from imageURL: URL, imagePath: String, to dest: URL) {
        let dest = dest.appendingPathComponent("assets")
        let fileName = imageURL.lastPathComponent

        if !FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: false, attributes: nil)
        }

        do {
            try FileManager.default.moveItem(at: imageURL, to: dest.appendingPathComponent(fileName))

            let prefix = "]("
            let postfix = ")"

            let find = prefix + imagePath + postfix
            let replace = prefix + "assets/" + imageURL.lastPathComponent + postfix

            guard find != replace else { return }

            while note.content.mutableString.contains(find) {
                let range = note.content.mutableString.range(of: find)
                note.content.replaceCharacters(in: range, with: replace)
            }
        } catch {
            print("Enc error: \(error)")
        }
    }

    private func moveFilesAssetsToFlat(content: URL, src: URL, project: Project) {
        guard let content = try? String(contentsOf: content) else { return }

        let mutableContent = NSMutableAttributedString(attributedString: NSAttributedString(string: content))

        let imagesMeta = getAllImages(content: mutableContent)
        for imageMeta in imagesMeta {
            let fileName = imageMeta.url.lastPathComponent
            var dst: URL?
            var prefix = "files/"

            if imageMeta.url.isImage {
                prefix = "i/"
            }

            dst = project.url.appendingPathComponent(prefix + fileName)

            guard let moveTo = dst else { continue }

            let dstDir = project.url.appendingPathComponent(prefix)
            let moveFrom = src.appendingPathComponent("assets/" + fileName)

            do {
                if !FileManager.default.fileExists(atPath: dstDir.path) {
                    try? FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: false, attributes: nil)
                }

                try FileManager.default.moveItem(at: moveFrom, to: moveTo)

            } catch {
                if let fileName = ImagesProcessor.getFileName(from: moveTo, to: dstDir, ext: moveTo.pathExtension) {

                    let moveTo = dstDir.appendingPathComponent(fileName)
                    try? FileManager.default.moveItem(at: moveFrom, to: moveTo)
                }
            }

            let find = "](assets/" + fileName + ")"
            let replace = "](" + prefix + fileName + ")"

            guard find != replace else { return }

            while mutableContent.mutableString.contains(find) {
                let range = mutableContent.mutableString.range(of: find)
                mutableContent.replaceCharacters(in: range, with: replace)
            }

            try? mutableContent.string.write(to: url, atomically: true, encoding: String.Encoding.utf8)
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
        var password = self.password

        SSZipArchive.createZipFile(atPath: textPackURL.path, withContentsOfDirectory: baseTextPack.path)

        do {
            if password == nil {
                let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")
                password = try item.readPassword()
            }

            guard let unwrappedPassword = password else { return }

            let data = try Data(contentsOf: textPackURL)
            let encryptedData = RNCryptor.encrypt(data: data, withPassword: unwrappedPassword)
            try encryptedData.write(to: self.url)

            let attributes = getFileAttributes()
            try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)

            print("FSNotes successfully writed encrypted data for: \(title)")

            try FileManager.default.removeItem(at: textPackURL)
        } catch {
            return
        }
    }

    public func unLock(password: String) -> Bool {
        let sharedStorage = Storage.sharedInstance()

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

            load(tags: false)
            loadTitle()
            
            invalidateCache()

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

            let newURL = project.url.appendingPathComponent(name + ".textbundle", isDirectory: false)
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

            invalidateCache()
            load()
            parseURL()

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
            parseURL()
            
            return true

        } catch {
            print("Encryption removing error: \(error)")

            return false
        }
    }

    public func encrypt(password: String) -> Bool {
        if container == .encryptedTextPack {
            return false
        }
        
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
            parseURL()
            
            try encrypted.write(to: encryptedURL)
            try FileManager.default.removeItem(at: originalSrc)
            try FileManager.default.removeItem(at: textPackURL)

            cleanOut()
            removeTempContainer()
            invalidateCache()

            return true
        } catch {
            print("Encyption error: \(error)")

            return false
        }
    }
    
    public func encryptAndUnlock(password: String) {
        if encrypt(password: password) {
            _ = unLock(password: password)
        }
    }

    public func cleanOut() {
        isParsed = false
        imageUrl = nil
        cacheHash = nil
        content = NSMutableAttributedString(string: String())
        preview = String()
        title = String()
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

    public func isEncryptedAndLocked() -> Bool {
        return container == .encryptedTextPack && decryptedTemporarySrc == nil
    }

    public func lock() -> Bool {
        guard let temporaryURL = self.decryptedTemporarySrc else { return false }

        while true {
            if Storage.sharedInstance().ciphertextWriter.operationCount == 0 {
                print("Note \"\(title)\" successfully locked.")

                container = .encryptedTextPack
                cleanOut()
                parseURL()

                try? FileManager.default.removeItem(at: temporaryURL)
                self.decryptedTemporarySrc = nil

                return true
            }

            usleep(100000)
        }
    }

    public func showIconInList() -> Bool {
        return (isPinned || isEncrypted() || isPublished())
    }

    public func getShortTitle() -> String {
        let fileName = getFileName()

        if fileName.isValidUUID {
            return "▽"
        }

        return fileName
    }

    public func getTitle() -> String? {
        if isEncrypted() && !isUnlocked() {
            return getFileName()
        }

        #if os(iOS)
        if !project.firstLineAsTitle {
            return getFileName()
        }
        #endif

        if title.count > 0 {
            if title.isValidUUID && (
                UserDefaultsManagement.firstLineAsTitle || project.firstLineAsTitle
            ) {
                return nil
            }

            if title.starts(with: "![") {
                return nil;
            }
            
            return title
        }

        if getFileName().isValidUUID {
            let previewCharsQty = preview.count
            if previewCharsQty > 0 {
                return "Untitled Note"
            }
        }

        return nil
    }

    public func getGitPath() -> String {
        var path = name

    #if NOT_EXTENSION || os(OSX)
        if let gitPath = project.getGitPath() {
            path = gitPath + "/" + name
        }
        
        if isTextBundle(), let text = getContentFileURL()?.lastPathComponent {
            return path + "/" + text
        }
    #endif

        return path
    }
    
    public func getGitCheckoutPath() -> String {
        var path = name.recode4byteString()

    #if NOT_EXTENSION || os(OSX)
        if let gitPath = project.getGitPath() {
            path = gitPath + "/" + name
        }
    #endif

        return path
    }

    public func rename(to name: String) {
        var name = name
        var i = 1

        while project.fileExist(fileName: name, ext: url.pathExtension) {

            // disables renaming loop
            if fileName.startsWith(string: name) {
                return
            }

            let items = name.split(separator: " ")

            if let last = items.last, let position = Int(last) {
                let full = items.dropLast()

                name = full.joined(separator: " ") + " " + String(position + 1)

                i = position + 1
            } else {
                name = name + " " + String(i)

                i += 1
            }
        }

        let isPinned = self.isPinned
        let dst = getNewURL(name: name)

        removePin()

        if isEncrypted() {
            _ = lock()
        }

        if move(to: dst) {
            url = dst
            parseURL()
        }

        if isPinned {
            addPin()
        }
    }

    public func getCursorPosition() -> Int? {
        var position: Int?

        if let data = try? url.extendedAttribute(forName: "co.fluder.fsnotes.cursor") {
            position = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in
                ptr.load(as: Int.self)
            }

            return position
        }

        return nil
    }

    public func addTag(_ name: String) {
        guard !tags.contains(name) else { return }

        let lastParRange = content.mutableString.paragraphRange(for: NSRange(location: content.length, length: 0))
        let string = content.attributedSubstring(from: lastParRange).string.trim()

        if string.count != 0 && (
            !string.starts(with: "#") || string.starts(with: "# ")
        ) {
            let newLine = NSAttributedString(string: "\n\n")
            content.append(newLine)
        }

        var prefix = String()
        if string.starts(with: "#") {
            prefix += " "
        }

        content.append(NSAttributedString(string: prefix + "#" + name))
        save()
    }

    public func resetAttributesCache() {
        cacheHash = nil
    }
    
    public func getLatinName() -> String {
        let name = (self.fileName as NSString)
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? self.fileName
        
        return name.replacingOccurrences(of: " ", with: "_")
    }
    
    public func isPublished() -> Bool {
        return apiId != nil || uploadPath != nil
    }
    
    public func convertContainer(to: NoteContainer) {
        if to == .textBundleV2 {
            let tempUrl = convertFlatToTextBundle()
            
            let name = url.deletingPathExtension().lastPathComponent
            let uniqueURL = NameHelper.getUniqueFileName(name: name, project: project, ext: "textbundle")

            do {
                let oldUrl = url
                url = uniqueURL
                try FileManager.default.moveItem(at: tempUrl, to: uniqueURL)
                try FileManager.default.removeItem(at: oldUrl)
            } catch {/*_*/}
        } else {
            let name = url.deletingPathExtension().lastPathComponent
            
            convertTextBundleToFlat(name: name)
        }
        
        invalidateCache()
        load()
        parseURL()
    }
}
