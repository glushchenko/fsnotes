//
//  NoteMO+CoreDataClass.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/24/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//
//

import Foundation

public class Note: NSObject  {
    @objc var title: String = ""
    var project: Project
    var type: NoteType = .Markdown
    var url: URL!
    var content: NSMutableAttributedString = NSMutableAttributedString()
    var creationDate: Date? = Date()
    var isCached = false
    var sharedStorage = Storage.sharedInstance()
    var tagNames = [String]()
    let dateFormatter = DateFormatter()
    let undoManager = UndoManager()
    
    public var name: String = ""
    public var preview: String = ""
    public var firstLineTitle: String?

    public var isPinned: Bool = false
    public var modifiedLocalAt = Date()

    public var imageUrl: [URL]?
    public var isParsed = false
    private var caching = false
    
    init(url: URL, with project: Project) {
        self.url = url
        self.project = project
        super.init()

        self.parseURL(loadProject: false)
    }
    
    init(name: String? = nil, project: Project? = nil, type: NoteType? = nil) {
        let project = project ?? Storage.sharedInstance().getMainProject()
        let name = name ?? String()

        self.project = project
        self.name = name        
        self.type = type ?? NoteType.withExt(rawValue: UserDefaultsManagement.storageExtension)
        
        if let uniqURL = Note.getUniqueFileName(name: name, project: project, type: self.type) {
            url = uniqURL
        }

        super.init()
        self.parseURL()
    }
    
    public func loadProject(url: URL) {
        self.url = url
        
        if let project = sharedStorage.getProjectBy(url: url) {
            self.project = project
        }
    }
    
    func initURL() {
        if let uniqURL = Note.getUniqueFileName(name: name, project: project, type: type) {
            url = uniqURL
        }
        
        parseURL()
    }
    
    func load(_ newUrl: URL) {
        url = newUrl
        type = NoteType.withExt(rawValue: url.pathExtension)
        parseURL()
        
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
            if let attributedString = getContent() {
                content = NSMutableAttributedString(attributedString: attributedString)
            }
            loadModifiedLocalAt()
            return true
        }
        
        return false
    }
    
    func loadModifiedLocalAt() {
        guard let modifiedAt = getFileModifiedDate() else {
            modifiedLocalAt = Date()
            return
        }

        modifiedLocalAt = modifiedAt
    }
    
    public func getFileModifiedDate() -> Date? {
        do {
            var path = url.path
            if self.type == .TextBundle {
                path = url.appendingPathComponent("text.markdown").path
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

                if let uniqURL = Note.getUniqueFileName(name: title, project: project, type: type) {
                    destination = uniqURL
                }
            }

            try FileManager.default.moveItem(at: url, to: destination)
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
    func removeFile() -> Array<URL>? {
        if FileManager.default.fileExists(atPath: url.path) {
            if isTrash() {
                try? FileManager.default.removeItem(at: url)
                return nil
            }

            var resultingItemUrl: NSURL?
            if #available(iOS 11.0, *) {
                try? FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemUrl)

                if let result = resultingItemUrl, let path = result.path {
                    return [URL(fileURLWithPath: path), url]
                }
            } else {
                let reserveName = "\(Int(Date().timeIntervalSince1970)) \(name)"
                guard let reserveDst = getTrashURL()?.appendingPathComponent(reserveName) else { return nil }
                try? FileManager.default.moveItem(at: url, to: reserveDst)

                return [reserveDst, url]
            }

            return nil
        }
        
        return nil
    }
    #endif

    #if os(OSX)
    func removeFile() -> Array<URL>? {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                if isTrash() {
                    try? FileManager.default.removeItem(at: url)
                    return nil
                }

                var resultingItemUrl: NSURL?

                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemUrl)

                    if let dst = resultingItemUrl, let path = dst.path {
                        NSLog("Note moved to trash: \(name)")

                        return [URL(fileURLWithPath: path), url]
                    }
                } catch {
                    return nil
                }
            }
        } catch let error as NSError {
            NSLog("Remove went wrong: \(error)")
            return nil
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
        
    public func getPreviewLabel(with text: String? = nil) -> String {
        var preview: String = ""
        let content = text ?? self.content.string

        if content.count > 250 {
            let startIndex = content.index((content.startIndex), offsetBy: 0)
            let endIndex = content.index((content.startIndex), offsetBy: 250)
            preview = String(content[startIndex...endIndex])
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

        return getPreviewLabel(with: nil)
    }
    
    @objc func getDateForLabel() -> String {
        let calendar = NSCalendar.current
        if calendar.isDateInToday(modifiedLocalAt) {
            return dateFormatter.formatTimeForDisplay(modifiedLocalAt)
        }
        else {
            return dateFormatter.formatDateForDisplay(modifiedLocalAt)
        }
    }

    @objc func getCreationDateForLabel() -> String? {
        guard let creationDate = self.creationDate else { return nil }

        let calendar = NSCalendar.current
        if calendar.isDateInToday(creationDate) {
            return dateFormatter.formatTimeForDisplay(creationDate)
        }
        else {
            return dateFormatter.formatDateForDisplay(creationDate)
        }
    }
    
    func getContent() -> NSAttributedString? {
        let options = getDocOptions()
        var url = self.url

        if type == .TextBundle {
            url?.appendPathComponent("text.markdown")
        }

        guard let docUrl = url else { return nil }

        do {
            return try NSAttributedString(url: docUrl, options: options, documentAttributes: nil)
        } catch {
            if let data = try? Data(contentsOf: docUrl) {
            let encoding = NSString.stringEncoding(for: data, encodingOptions: nil, convertedString: nil, usedLossyConversion: nil)

                let options = getDocOptions(with: String.Encoding.init(rawValue: encoding))
                return try? NSAttributedString(url: docUrl, options: options, documentAttributes: nil)
            }
        }
        
        return nil
    }
    
    func loadContent() {
        if let content = getContent() {
            self.content = NSMutableAttributedString(attributedString: content)
        }
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
    
    public static func getUniqueFileName(name: String, i: Int = 0, project: Project, type: NoteType) -> URL? {
        let defaultName = "Untitled Note"
        var i = i
        var name = name
            .trimmingCharacters(in: CharacterSet.whitespaces)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: ":")

        if name.isEmpty {
            name = defaultName
        }
        
        var fileUrl = project.url
        fileUrl.appendPathComponent(name)
        fileUrl.appendPathExtension(type.rawValue)
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileUrl.path) {
            let regex = try? NSRegularExpression(pattern: "(.+)\\s(\\d)+", options: .caseInsensitive)

            if let result = regex?.firstMatch(in: name, range: NSRange(0..<name.count)) {

                if let r = Range(result.range(at: 1), in: name) {
                    name = String(name[r])
                }

                if let r = Range(result.range(at: 2), in: name) {
                    let digit = name[r]

                    if let converted = Int(digit) {
                        i = converted
                    }
                }
            }

            let j = i + 1
            let newName = name + " " + String(j)
            return Note.getUniqueFileName(name: newName, i: j, project: project, type: type)
        }
        
        return fileUrl
    }
    
    func isRTF() -> Bool {
        return (type == .RichText)
    }
    
    func isMarkdown() -> Bool {
        return (type == .Markdown) || (type == .TextBundle)
    }
    
    func addPin(cloudSave: Bool = true) {
        sharedStorage.pinned += 1
        isPinned = true
        
        #if CLOUDKIT || os(iOS)
        if cloudSave {
            sharedStorage.saveCloudPins()
        }
        return
        #endif
        
        #if os(OSX)
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
            return
            #endif
            
            #if os(OSX)
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
    
    func parseURL(loadProject: Bool = true) {
        if (url.pathComponents.count > 0) {
            name = url.pathComponents.last!
            type = .withExt(rawValue: url.pathExtension)
            title = url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")
        }

        if loadProject {
            self.loadProject(url: url)
        }
    }
        
    public func save() {
        if self.isMarkdown() {
            self.content = self.content.unLoadCheckboxes()
            
            if UserDefaultsManagement.liveImagesPreview {
                self.content = self.content.unLoadImages(note: self)
            }
        }
        
        self.save(attributedString: self.content)
    }

    private func save(attributedString: NSAttributedString) {
        let attributes = getFileAttributes()
        
        do {
            let fileWrapper = getFileWrapper(attributedString: attributedString)

            if type == .TextBundle {
                if let uurl = self.url, !FileManager.default.fileExists(atPath: uurl.path) {
                    try? FileManager.default.createDirectory(at: uurl, withIntermediateDirectories: false, attributes: nil)
                    self.writeTextBundleInfo(url: uurl)
                }
            }

            let url = getContentFileURL()
            try fileWrapper.write(to: url, options: .atomic, originalContentsURL: nil)
            try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        } catch {
            NSLog("Write error \(error)")
            return
        }

        sharedStorage.add(self)
    }

    private func getContentFileURL() -> URL {
        if type == .TextBundle {
            return url.appendingPathComponent("text.markdown")
        }

        return url
    }

    public func getFileWrapper(with imagesWrapper: FileWrapper? = nil) -> FileWrapper {
        let fileWrapper = getFileWrapper(attributedString: content)

        if type == .TextBundle {

            let fileWrapper = getFileWrapper(attributedString: content)
            let info = """
            {
                "transient" : true,
                "type" : "net.daringfireball.markdown",
                "creatorIdentifier" : "co.fluder.fsnotes",
                "version" : 2
            }
            """
            let infoWrapper = self.getFileWrapper(attributedString: NSAttributedString(string: info))

            let textBundle = FileWrapper.init(directoryWithFileWrappers: [
                    "text.markdown": fileWrapper,
                    "info.json": infoWrapper
                ])

            let assetsWrapper = imagesWrapper ?? getAssetsFileWrapper()
            textBundle.addFileWrapper(assetsWrapper)

            return textBundle
        }

        fileWrapper.filename = name

        return fileWrapper
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
        
        let info = """
        {
            "transient" : true,
            "type" : "net.daringfireball.markdown",
            "creatorIdentifier" : "co.fluder.fsnotes",
            "version" : 2
        }
        """

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
        return url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")
    }
    
    func markdownCache() {
        guard isMarkdown() && !self.caching && !self.isCached else { return }

        self.caching = true

        #if NOT_EXTENSION || os(OSX)
        NotesTextProcessor.fullScan(note: self, async: false)
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
        
        if let i = tagNames.index(of: name) {
            tagNames.remove(at: i)
        }
        
        if sharedStorage.noteList.first(where: {$0.tagNames.contains(name)}) == nil {
            if let i = sharedStorage.tagNames.index(of: name) {
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
        
        if type == .TextBundle {
            return url.appendingPathComponent(imageName)
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
    public func duplicate() {
        var url: URL = self.url

        let ext = url.pathExtension
        url.deletePathExtension()

        let name = url.lastPathComponent
        url.deleteLastPathComponent()

        let now = dateFormatter.formatForDuplicate(Date())
        url.appendPathComponent(name + " " + now)
        url.appendPathExtension(ext)

        try? FileManager.default.copyItem(at: self.url, to: url)
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

        if type == .TextBundle {
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

        return title
    }
}
