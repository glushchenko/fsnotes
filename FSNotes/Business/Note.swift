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
    public var originalExtension: String?
    
    public var isBlocked: Bool = false

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
    public var attachments: [URL]?
    public var isParsed = false

    private var decryptedTemporarySrc: URL?
    private var firstLineAsTitle = false

    public var isLoaded = false
    public var isLoadedFromCache = false

    public var password: String?

    public var cacheLock: Bool = false
    public var cacheHash: UInt64?
    
    public var uploadPath: String?
    public var apiId: String?
    
    public var previewState: Bool = false

    private var selectedRange: NSRange?
    private var contentOffset = CGPoint()

    public var codeBlockRangesCache: [NSRange]?

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
        let project = project ?? Storage.shared().getMainProject()
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
        
        if meta.title.count > 0 || meta.imageUrl != nil {
            isParsed = true
        }
        
        url = meta.url
        attachments = meta.attachments
        imageUrl = meta.imageUrl
        title = meta.title
        preview = meta.preview
        modifiedLocalAt = meta.modificationDate
        creationDate = meta.creationDate
        isPinned = meta.pinned
        tags = meta.tags
        selectedRange = meta.selectedRange
        self.project = project

        super.init()

        parseURL(loadProject: false)
    }
    
    public func fileSize(atPath path: String) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? Int64 {
                return fileSize
            }
        } catch {
            print("Error retrieving file size: \(error.localizedDescription)")
        }
        return nil
    }
    
    public func isValidForCaching() -> Bool {
        return isLoaded || title.count > 0 || isEncrypted() || imageUrl != nil
    }

    func getMeta() -> NoteMeta {
        let date = creationDate ?? Date()
        return NoteMeta(
            url: url,
            attachments: attachments,
            imageUrl: imageUrl,
            title: title,
            preview: preview,
            modificationDate: modifiedLocalAt,
            creationDate: date,
            pinned: isPinned,
            tags: tags, 
            selectedRange: selectedRange
        )
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
        let sharedStorage = Storage.shared()
        
        if let project = sharedStorage.getProjectByNote(url: url) {
            self.project = project
        }
    }

    public func forceLoad(skipCreateDate: Bool = false, loadTags: Bool = true) {
        invalidateCache()
        load(tags: loadTags)

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
            
            if isTextBundle() {
                writeTextBundleInfo(url: getURL())
            }
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
            
            if isTextBundle() {
                writeTextBundleInfo(url: getURL())
            }
            
            return true
        } catch {
            return false
        }
    }
    
    private func readTitleAndPreview() -> (String?, String?) {
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
            print("Can not open the file.")
            return (nil, nil)
        }
        defer { fileHandle.closeFile() }
        
        var saveChars = false
        var title = String()
        var preview = String()
        
        while let char = String(data: fileHandle.readData(ofLength: 1), encoding: .utf8) {
            if char == "\n" {
                if saveChars {
                    preview += " "
                } else {
                    saveChars = true
                }
                continue
            }
            
            if saveChars {
                preview += char
                if preview.count >= 100 {
                    break
                }
            } else {
                title += char
            }
        }
        
        preview = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (title, preview)
    }


    public func uiLoad() {
        if let size = fileSize(atPath: self.url.path), size > 100000 {
            loadFileName()
            
            let data = readTitleAndPreview()
            if let title = data.0 {
                self.title = title.trimMDSyntax()
            }
            
            if let preview = data.1 {
                self.preview = preview.trimMDSyntax()
            }
            
            return
        }
        
        load(tags: true)
    }
    
    func load(tags: Bool = true) {
        #if SHARE_EXT
            return
        #endif

        if let attributedString = getContent() {
            cacheHash = nil
            content = attributedString.loadAttachments(self)
        }

        loadFileName()
        loadPreviewInfo()
        
        if !isTrash() && tags {
            loadTags()
        }

        isLoaded = true
    }

    func reload() -> Bool {
        guard let modifiedAt = getFileModifiedDate() else { return false }
                        
        if (modifiedAt != modifiedLocalAt) {
            if let attributedString = getContent() {
                cacheHash = nil
                content = attributedString.loadAttachments(self)
                cacheCodeBlocks()
            }

            loadModifiedLocalAt()
            return true
        }
        
        return false
    }

    public func forceReload() {
        if container != .encryptedTextPack, let attributedString = getContent() {
            cacheHash = nil
            content = attributedString.loadAttachments(self)
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

        if isUnlocked() {
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: self.url.path)
                return attr[FileAttributeKey.modificationDate] as? Date
            } catch {/*_*/}
        }

        if UserDefaultsManagement.useTextBundleMetaToStoreDates && isTextBundle() {
            let textBundleURL = url
            let json = textBundleURL.appendingPathComponent("info.json")

            if let jsonData = try? Data(contentsOf: json),
               let info = try? JSONDecoder().decode(TextBundleInfo.self, from: jsonData),
               let modified = info.modified {

                return Date(timeIntervalSince1970: TimeInterval(modified))
            }
        }

        if let contentUrl = getContentFileURL() {
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: contentUrl.path)

                return attr[FileAttributeKey.modificationDate] as? Date
            } catch {
                NSLog("Note modification date load error: \(error.localizedDescription)")
            }
        }

        return
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
    }

    public func getFileCreationDate() -> Date? {
        let url = getURL()

        if isUnlocked() {
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: self.url.path)
                return attr[FileAttributeKey.creationDate] as? Date
            } catch {/*_*/}
        }

        if UserDefaultsManagement.useTextBundleMetaToStoreDates && isTextBundle() {
            let textBundleURL = url
            let json = textBundleURL.appendingPathComponent("info.json")

            if let jsonData = try? Data(contentsOf: json),
               let info = try? JSONDecoder().decode(TextBundleInfo.self, from: jsonData),
               let created = info.created {
                
                return Date(timeIntervalSince1970: TimeInterval(created))
            }
        }

        if let contentUrl = getContentFileURL() {
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: contentUrl.path)

                return attr[FileAttributeKey.creationDate] as? Date
            } catch {
                NSLog("Note creation date load error: \(error.localizedDescription)")
            }
        }

        return
            (try? url.resourceValues(forKeys: [.creationDateKey]))?
                .creationDate
    }
    
    func move(to: URL, project: Project? = nil, forceRewrite: Bool = false) -> Bool {
        let sharedStorage = Storage.shared()

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
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "")
        
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

                #if IOS_APP
                    moveHistory(src: src, dst: dst)
                #endif
            }
        } else {
            _ = removeFile()

            if self.isPinned {
                removePin()
            }

            #if IOS_APP
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
                    let urls = content.getImagesAndFiles()
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
                    if let trash = Storage.shared().getDefaultTrash() {
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

            if let trash = Storage.shared().getDefaultTrash() {
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
            do {
                try FileManager.default.removeItem(at: url)
            } catch let error as NSError {
                Swift.print("Remove file error: \(error.localizedDescription)")
                Swift.print("Error details: \(error.userInfo)")
            }

            if type == .Markdown && container == .none {
                let urls = content.getImagesAndFiles()
                for url in urls {
                    try? FileManager.default.removeItem(at: url.url)
                }
            }

            return nil
        }

        do {
            guard let dst = Storage.shared().trashItem(url: url) else {
                var resultingItemUrl: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemUrl)

                guard let dst = resultingItemUrl else { return nil }

                let originalURL = url

                overwrite(url: dst as URL)

                return [self.url, originalURL]
            }

            if let trash = Storage.shared().getDefaultTrash() {
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
            let imagesMeta = content.getImagesAndFiles()
            for imageMeta in imagesMeta {
                let imagePath = project.url.appendingPathComponent(imageMeta.path).path
                project.storage.hideImages(directory: imagePath, srcPath: imagePath)

                // Copy if image used more then one time on project
                let copy = self.project.countNotes(contains: imageMeta.url) > 0
                move(from: imageMeta.url, imagePath: imageMeta.path, to: project, copy: copy)
            }

            if imagesMeta.count > 0 {
                if save() {
                    Storage.shared().add(self)
                }
            }
        }
    }
    
    private func getDefaultTrashURL() -> URL? {
        if let url = Storage.shared().getDefaultTrash()?.url {
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
        if project.settings.isFirstLineAsTitle() {
            return preview
        }

        return getPreviewLabel()
    }
    
    @objc func getDateForLabel() -> String {
        guard !UserDefaultsManagement.hideDate else { return String() }

        let date = self.project.storage.getSortByState() == .creationDate
            ? creationDate
            : modifiedLocalAt

        guard let date = date else { return String() }

        if NSCalendar.current.isDateInToday(date) {
            return dateFormatter.formatTimeForDisplay(date)
        } else {
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
    
    func getContent() -> NSMutableAttributedString? {
        guard container != .encryptedTextPack, let url = getContentFileURL() else { return nil }

        do {
            return try NSMutableAttributedString(url: url, options: [
                .documentType : NSAttributedString.DocumentType.plain,
                .characterEncoding : NSNumber(value: String.Encoding.utf8.rawValue)
            ], documentAttributes: nil)
        } catch {
            if let data = try? Data(contentsOf: url) {
                let encoding = NSString.stringEncoding(for: data, encodingOptions: nil, convertedString: nil, usedLossyConversion: nil)

                return try? NSMutableAttributedString(url: url, options: [
                    .documentType : NSAttributedString.DocumentType.plain,
                    .characterEncoding : NSNumber(value: encoding)
                ], documentAttributes: nil)
            }
        }
        
        return nil
    }

    func getAltContent(url: URL) -> NSAttributedString? {
        guard container != .encryptedTextPack else { return nil }

        do {
            return try NSAttributedString(url: url, options: [
                .documentType : NSAttributedString.DocumentType.plain,
                .characterEncoding : NSNumber(value: String.Encoding.utf8.rawValue)
            ], documentAttributes: nil)
        } catch {

            if let data = try? Data(contentsOf: url) {
            let encoding = NSString.stringEncoding(for: data, encodingOptions: nil, convertedString: nil, usedLossyConversion: nil)

                return try? NSAttributedString(url: url, options: [
                    .documentType : NSAttributedString.DocumentType.plain,
                    .characterEncoding : NSNumber(value: encoding)
                ], documentAttributes: nil)
            }
        }

        return nil
    }
    
    func isMarkdown() -> Bool {
        return type == .Markdown
    }
    
    func addPin(cloudSave: Bool = true) {
        isPinned = true
        
        if cloudSave {
            Storage.shared().saveCloudPins()
        }
    }

    func removePin(cloudSave: Bool = true) {
        if isPinned {
            isPinned = false
            
            if cloudSave {
                Storage.shared().saveCloudPins()
            }
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
        #if IOS_APP || os(OSX)
            let mutable = NotesTextProcessor.convertAppTags(in: self.content.unloadAttachments(), codeBlockRanges: codeBlockRangesCache)
        let content = NotesTextProcessor.convertAppLinks(in: mutable, codeBlockRanges: codeBlockRangesCache)
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
                type = .Markdown
                container = .textBundle

                let infoUrl = url.appendingPathComponent("info.json")

                if FileManager.default.fileExists(atPath: infoUrl.path) {
                    do {
                        let jsonData = try Data(contentsOf: infoUrl)
                        let info = try JSONDecoder().decode(TextBundleInfo.self, from: jsonData)

                        if info.version == 0x02 {
                            type = NoteType.withUTI(rawValue: info.type)
                            container = .textBundleV2
                            originalExtension = info.flatExtension

                            if UserDefaultsManagement.useTextBundleMetaToStoreDates {
                                if let created = info.created {
                                    creationDate = Date(timeIntervalSince1970: TimeInterval(created))
                                }

                                if let modified = info.modified {
                                    modifiedLocalAt = Date(timeIntervalSince1970: TimeInterval(modified))
                                }
                            }
                        }
                    } catch {
                        print("TB loading error \(error)")
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
        if !project.settings.isFirstLineAsTitle() {
            title = url
                .deletingPathExtension()
                .pathComponents
                .last!
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "/", with: "")
        }
    }

    private func loadFileName() {
        fileName = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "")
    }

    public func getFileName() -> String {
        return fileName
    }

    public func save(attributed: NSAttributedString) {
        if container == .encryptedTextPack { return }

        let copy = attributed.copy() as? NSAttributedString
        modifiedLocalAt = Date()

        let operation = BlockOperation()
        operation.addExecutionBlock({
            if let copy = copy {
                let mutable = NSMutableAttributedString(attributedString: copy)
                self.save(content: mutable)

                usleep(1000000)

                if !operation.isCancelled {
                    self.isBlocked = false
                }
            }
        })

        Storage.shared().plainWriter.cancelAllOperations()
        Storage.shared().plainWriter.addOperation(operation)
    }

    public func save(content: NSMutableAttributedString) {
        self.content = content

        let copy = content.unloadAttachments()
        modifiedLocalAt = Date()

        if write(attributedString: copy) {
            Storage.shared().add(self)
        }
    }

    public func replace(tag: String, with string: String) {
        content.replaceTag(name: tag, with: string)
        _ = save()
    }

    public func delete(tag: String) {
        content.replaceTag(name: tag, with: "")
        _ = save()
    }
        
    public func save() -> Bool {
        let attributedString = self.content.unloadAttachments()

        return write(attributedString: attributedString)
    }

    private func write(attributedString: NSAttributedString) -> Bool {
        let url = getURL()
        let attributes = getFileAttributes()
        
        do {
            let fileWrapper = getFileWrapper(attributedString: attributedString)

            if isTextBundle() {
                let jsonUrl = url.appendingPathComponent("info.json")
                let fileExist = FileManager.default.fileExists(atPath: jsonUrl.path)

                if !fileExist {
                    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
                }

                if UserDefaultsManagement.useTextBundleMetaToStoreDates || !fileExist {
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
                Storage.shared().ciphertextWriter.cancelAllOperations()
                Storage.shared().ciphertextWriter.addOperation {
                    guard Storage.shared().ciphertextWriter.operationCount == 1 else { return }
                    self.writeEncrypted()
                }
            }
        } catch {
            NSLog("Write error \(error)")
            return false
        }

        return true
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
    
    private func getTextBundleJsonInfo() -> String {
        var data = [
            "transient": "true",
            "type": "\"\(type.uti)\"",
            "creatorIdentifier": "\"co.fluder.fsnotes\"",
            "version": "2"
        ]

        if let originalExtension = originalExtension {
            data["flatExtension"] = "\"\(originalExtension)\""
        }

        if UserDefaultsManagement.useTextBundleMetaToStoreDates {
            let creationDate = self.creationDate ?? Date()
            let modificationDate = self.modifiedLocalAt

            data["created"] = "\(Int(creationDate.timeIntervalSince1970))"
            data["modified"] = "\(Int(modificationDate.timeIntervalSince1970))"
        }

        var result = [String]()

        for key in [
            "transient",
            "type",
            "creatorIdentifier",
            "version",
            "flatExtension",
            "created",
            "modified"
        ] {
            if let value = data[key] {
                result.append("    \"\(key)\" : \(value)")
            }
        }

        return "{\n" + result.joined(separator: ",\n") + "\n}"
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
        let url = getContentFileURL() ?? url
        var attributes: [FileAttributeKey: Any] = [:]
        
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {}

        attributes[.modificationDate] = modifiedLocalAt
        return attributes
    }
    
    func getFileWrapper(attributedString: NSAttributedString, forcePlain: Bool = false) -> FileWrapper {
        do {
            let range = NSRange(location: 0, length: attributedString.length)

            return try attributedString.fileWrapper(from: range, documentAttributes: [
                .documentType : NSAttributedString.DocumentType.plain,
                .characterEncoding : NSNumber(value: String.Encoding.utf8.rawValue)
            ])
        } catch {
            return FileWrapper()
        }
    }
        
    func getTitleWithoutLabel() -> String {
        let title = url.deletingPathExtension().pathComponents.last!
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "")

        if title.isValidUUID {
            return ""
        }

        return title
    }
    
    func isTrash() -> Bool {
        return project.isTrash
    }
    
    public func contains<S: StringProtocol>(terms: [S]) -> Bool {
        return name.localizedStandardContains(terms) || content.string.localizedStandardContains(terms)
    }

    public func loadTags() {
        if UserDefaultsManagement.inlineTags {
            _ = scanContentTags()
        }
    }
    
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

                    if let codeBlockRangesCache = codeBlockRangesCache {
                        for codeRange in codeBlockRangesCache {
                            if NSIntersectionRange(codeRange, range).length > 0 {
                                return
                            }
                        }
                    }

                    let spanBlock = FSParser.getSpanCodeBlockRange(content: content, range: range)
                    
                    if spanBlock == nil && isValid(tag: cleanTag) {
                        
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

        if tag.isHexColor() {
            return false
        }

        return true
    }
    
    public func getAttachmentFileUrl(name: String) -> URL? {
        if name.count == 0 {
            return nil
        }

        if name.starts(with: "http://") || name.starts(with: "https://") {
            return URL(string: name)
        }

        if isEncrypted() && (
            name.starts(with: "/i/") || name.starts(with: "i/")
        ) {
            return project.url.appendingPathComponent(name)
        }
        
        if isTextBundle() {
            return getURL().appendingPathComponent(name)
        }

        return project.url.appendingPathComponent(name)
    }

    public func dropImagesCache() {
        let items = content.getImagesAndFiles()

        for item in items{
            var temporary = URL(fileURLWithPath: NSTemporaryDirectory())
            temporary.appendPathComponent("ThumbnailsBigInline")

            let cacheUrl = temporary.appendingPathComponent(item.url.absoluteString.md5 + "." + item.url.pathExtension)
            try? FileManager.default.removeItem(at: cacheUrl)
        }
    }

    public func countCheckSum() -> String {
        let items = content.getImagesAndFiles()
        var size = UInt64(0)

        for item in items {
            size += item.url.fileSize
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

        if (title.count > 0 || imageUrl != nil) && self.isParsed {
            print("skip loading preview")
            return
        }

        var cleanText = content
        cleanText = cleanText.trimMDSyntax()

        if cleanText.startsWith(string: "---") {
            FSParser.yamlBlockRegex.matches(cleanText, range: NSRange(location: 0, length: cleanText.count)) { (result) -> Void in
                guard let range = result?.range(at: 1), range.location == 0 else { return }

                if let swiftRange = cleanText.swiftRange(from: range) {
                    let yamlText = cleanText[swiftRange]
                
                    self.loadYaml(components: yamlText.components(separatedBy: NSCharacterSet.newlines))
                    
                    cleanText = cleanText.replacingOccurrences(of: yamlText, with: "")
                }
            }
        }

        let components = cleanText
            .trim()
            .components(separatedBy: NSCharacterSet.newlines)
            .map { line in
                return line.replacingOccurrences(of: "^#+", with: "", options: .regularExpression)
            }
            .filter({ $0 != "" })

        if let first = components.first {
            if project.settings.isFirstLineAsTitle() {
                loadYaml(components: components)

                if title.count == 0 {
                    title = first.trim()
                    preview = getPreviewLabel(with: components.dropFirst().joined(separator: " "))
                    firstLineAsTitle = true
                } else {
                    preview = getPreviewLabel(with: components.joined(separator: " "))
                }
            } else {
                loadTitleFromFileName()
                self.preview = getPreviewLabel(with: components.joined(separator: " "))
            }
        } else {
            if !project.settings.isFirstLineAsTitle() {
                loadTitleFromFileName()
            } else {
                firstLineAsTitle = false
            }
        }

        imageUrl = getImagesFromContent()

        self.isParsed = true
    }

    public func getImagesFromContent() -> [URL] {
        var urls = [URL]()

        if !isLoaded {
            return imageUrl ?? urls
        }

        let range = NSRange(location: 0, length: content.length)
        content.enumerateAttribute(.attachment, in: range) { (value, vRange, _) in
            guard let meta = content.getMeta(at: vRange.location) else { return }

            if meta.url.isImage {
                urls.append(meta.url)
            }
        }

        return urls
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
        let fileName = url.deletingPathExtension().pathComponents.last!
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "")

        self.title = fileName

        firstLineAsTitle = false
    }

    public func invalidateCache() {
        self.imageUrl = nil
        self.preview = String()
        self.title = String()
        self.isParsed = false
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

        let imagesMeta = content.getImagesAndFiles()
        let mutableContent = content.unloadAttachments()

        // write textbundle body
        guard note.write(attributedString: mutableContent) else { return note.url }

        for imageMeta in imagesMeta {
            moveFilesFlatToAssets(attributedString: mutableContent, from: imageMeta.url, imagePath: imageMeta.path, to: note.url)
        }

        // write updated image pathes
        guard note.write(attributedString: mutableContent) else {
            return note.url
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

            moveFilesAssetsToFlat(src: textBundleURL, project: project)

            try? FileManager.default.removeItem(at: textBundleURL)
        }
    }

    private func moveFilesFlatToAssets(attributedString: NSMutableAttributedString, from imageURL: URL, imagePath: String, to dest: URL) {
        let dest = dest.appendingPathComponent("assets")

        guard let fileName = imageURL.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }

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

            while attributedString.mutableString.contains(find) {
                let range = attributedString.mutableString.range(of: find)
                attributedString.replaceCharacters(in: range, with: replace)
            }
        } catch {
            print("Enc error: \(error)")
        }
    }

    private func moveFilesAssetsToFlat(src: URL, project: Project) {
        let mutableContent =
            NSMutableAttributedString(attributedString: content).unloadAttachments()

        let imagesMeta = content.getImagesAndFiles()
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

            guard let escapedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { continue }

            let find = "](assets/" + escapedFileName + ")"
            let replace = "](" + prefix + escapedFileName + ")"

            guard find != replace else { return }

            while mutableContent.mutableString.contains(find) {
                let range = mutableContent.mutableString.range(of: find)
                mutableContent.replaceCharacters(in: range, with: replace)
            }
        }

        content = mutableContent
        _ = save()
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
        let sharedStorage = Storage.shared()

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

            invalidateCache()
            load(tags: false)
            loadTitle()
            
            self.password = password

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
            let textPackURL = getTempTextPackURL()
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

            self.decryptedTemporarySrc = nil
            self.password = nil

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
        let textPackURL = getTempTextPackURL()

        SSZipArchive.createZipFile(atPath: textPackURL.path, withContentsOfDirectory: baseTextPack.path)

        do {
            if let tempURL = temporaryFlatSrc {
                try FileManager.default.removeItem(at: tempURL)
            }

            let encryptedURL = 
                self.project.url
                .appendingPathComponent(fileName)
                .appendingPathExtension("etp")

            let data = try Data(contentsOf: textPackURL)
            let encrypted = RNCryptor.encrypt(data: data, withPassword: password)

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
            url = originalSrc
            parseURL()

            print("Encyption error: \(error) \(error.localizedDescription)")

            return false
        }
    }

    public func getTempTextPackURL() -> URL {
        let fileName = url.deletingPathExtension().lastPathComponent

        let textPackURL =
            URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(fileName, isDirectory: false)
                .appendingPathExtension("textpack")

        return textPackURL
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
            if Storage.shared().ciphertextWriter.operationCount == 0 {
                print("Note \"\(title)\" successfully locked.")

                container = .encryptedTextPack
                cleanOut()
                parseURL()

                try? FileManager.default.removeItem(at: temporaryURL)
                self.decryptedTemporarySrc = nil
                self.password = nil

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
        if !project.settings.isFirstLineAsTitle() {
            return getFileName()
        }
        #endif

        if title.count > 0 {
            if title.isValidUUID && project.settings.isFirstLineAsTitle() {
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
        if save() {
            Storage.shared().add(self)
        }
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

    public func getAutoRenameTitle() -> String? {
        if UserDefaultsManagement.naming != .autoRename && UserDefaultsManagement.naming != .autoRenameNew {
            return nil
        }
        
        if UserDefaultsManagement.naming == .autoRenameNew && isOlderThan30Seconds(from: creationDate) {
            return nil
        }
        
        if content.string.startsWith(string: "---") {
            loadPreviewInfo()
        }

        let title = title.trunc(length: 64)

        if fileName == title || title.count == 0 || isEncrypted() {
            return nil
        }

        if project.fileExist(fileName: title, ext: url.pathExtension) {
            return nil
        }

        return title
    }

    public func setSelectedRange(range: NSRange) {
        selectedRange = range
    }

    public func getSelectedRange() -> NSRange? {
        return selectedRange
    }

    public func setContentOffset(contentOffset: CGPoint) {
        self.contentOffset = contentOffset
    }

    public func getContentOffset() -> CGPoint {
        return contentOffset
    }

    public func getRelatedPath() -> String {
        return project.getNestedPath() + "/" + name
    }
    

    func isOlderThan30Seconds(from date: Date? = nil) -> Bool {
        guard let date = date else { return false }

        let thirtySecondsAgo = Date().addingTimeInterval(-30)
        return date < thirtySecondsAgo //Returns false if date is not older than 30 seconds
    }
    
    public func loadPreviewState() {
        previewState = project.settings.notesPreview.contains(name)
    }

    public func cacheCodeBlocks() {
    #if !SHARE_EXT
        let ranges = CodeBlockDetector.shared.findCodeBlocks(in: content)
        codeBlockRangesCache = ranges
    #endif
    }

    public func isInCodeBlockRange(range: NSRange) -> Bool {
        guard let codeBlockRangesCache = codeBlockRangesCache else { return false }

        for codeRange in codeBlockRangesCache {
            if NSIntersectionRange(range, codeRange).length > 0 {
                return true
            }
        }

        return false
    }

    public func save(attachment: Attachment) -> (String, URL)? {
        guard let data = attachment.data else { return nil }
        let preferredName = attachment.preferredName

        // Get attach dir
        let attachDir = getAttachDirectory(data: data)

        // Create if not exist
        if !FileManager.default.fileExists(atPath: attachDir.path, isDirectory: nil) {
            try? FileManager.default.createDirectory(at: attachDir, withIntermediateDirectories: true, attributes: nil)
        }

        guard let fileName = getFileName(dst: attachDir, preferredName: preferredName) else { return nil }

        let fileUrl = attachDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileUrl, options: .atomic)
        } catch {
            print("Attachment error: \(error)")
            return nil
        }

        let lastTwo = fileUrl.deletingLastPathComponent().lastPathComponent + "/" + fileUrl.lastPathComponent

        return (lastTwo, fileUrl)
    }

    public func getAttachDirectory(data: Data) -> URL {
        if isTextBundle() {
            return getURL().appendingPathComponent("assets", isDirectory: true)
        }

        let prefix = data.getFileType() != .unknown ? "i" : "files"

        return project.url.appendingPathComponent(prefix, isDirectory: true)
    }

    public func getFileName(dst: URL, preferredName: String? = nil) -> String? {
        var name = preferredName ?? UUID().uuidString.lowercased()
        let ext = (name as NSString).pathExtension

        while true {
            let destination = dst.appendingPathComponent(name)
            let icloud = destination.appendingPathExtension("icloud")

            if FileManager.default.fileExists(atPath: destination.path) || FileManager.default.fileExists(atPath: icloud.path) {
                let newBase = UUID().uuidString.lowercased()
                if ext.isEmpty {
                    name = newBase
                } else {
                    name = "\(newBase).\(ext)"
                }
                continue
            }

            return name
        }
    }

    public func saveSimple() -> Bool {
        return write(attributedString: content)
    }
}
