//
//  NoteMO+CoreDataClass.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/24/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//
//

import Foundation
import CoreData

public class Note: NSObject {
    @objc var title: String = ""
    var project: Project? = nil
    var type: NoteType = .Markdown
    var url: URL!
    var content: NSMutableAttributedString = NSMutableAttributedString()
    var syncSkipDate: Date?
    var syncDate: Date?
    var creationDate: Date? = Date()
    var isCached = false
    var sharedStorage = Storage.sharedInstance()
    var tagNames = [String]()

    public var name: String = ""
    public var isPinned: Bool = false
    public var modifiedLocalAt: Date?
    public var undoManager = UndoManager()

    init(url: URL) {
        self.url = url

        if let project = sharedStorage.getProjectBy(url: url) {
            self.project = project
        }
    }

    init(name: String, project: Project) {
        self.project = project
        self.name = name
        type = NoteType.withExt(rawValue: UserDefaultsManagement.storageExtension)
    }

    func initURL() {
        if let uniqURL = getUniqueFileName(name: name) {
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

        if !isTrash() {
            loadTags()
        }
    }

    func reload() -> Bool {
        guard let modifiedAt = getFileModifiedDate() else {
            return false
        }

        guard let prevModifiedAt = modifiedLocalAt else {
            return false
        }

        if (modifiedAt != prevModifiedAt) {
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

    func getFileModifiedDate() -> Date? {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            NSLog("Note modification date load error: \(error.localizedDescription)")
            return nil
        }
    }

    func rename(newName: String) {
        let to = getNewURL(name: newName)

        do {
            try FileManager.default.moveItem(at: url, to: to)
            print("File moved from \"\(url.deletingPathExtension().lastPathComponent)\" to \"\(to.deletingPathExtension().lastPathComponent)\"")
        } catch {}
    }

    func getNewURL(name: String) -> URL {
        let escapedName = name
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: ":")

        var newUrl = url.deletingLastPathComponent()
        newUrl.appendPathComponent(escapedName + "." + url.pathExtension)
        return newUrl
    }

    // Return URL moved in
    func removeFile() -> Array<URL>? {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
            #if os(OSX)
                if isTrash() {
                    try FileManager.default.removeItem(at: url)
                } else {
                    guard let dst = getTrashURL()?.appendingPathComponent(name) else { return nil }

                    do {
                        try FileManager.default.moveItem(at: url, to: dst)
                    } catch {
                        let reserveName = "\(Int(Date().timeIntervalSince1970)) \(name)"
                        guard let reserveDst = getTrashURL()?.appendingPathComponent(reserveName) else { return nil }

                        try FileManager.default.moveItem(at: url, to: reserveDst)

                        return [reserveDst, url]
                    }

                    return [dst, url]
                }
            #else
                try FileManager.default.removeItem(at: url)
            #endif
                print("Note moved to trash: \(name)")
            }
        } catch let error as NSError {
            print("Remove went wrong: \(error)")
            return nil
        }

        return nil
    }

    private func getTrashURL() -> URL? {
        if let url = sharedStorage.getTrash(url: url) {
            return url
        }

        return nil
    }

    @objc func getPreviewForLabel() -> String {
        var preview: String = ""
        let content = self.content.string

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

    @objc func getDateForLabel() -> String {
        guard let date = self.modifiedLocalAt else {
            return "-"
        }

        let dateFormatter = DateFormatter()
        let calendar = NSCalendar.current
        if calendar.isDateInToday(date) {
            return dateFormatter.formatTimeForDisplay(date)
        }
        else {
            return dateFormatter.formatDateForDisplay(date)
        }
    }

    func getContent() -> NSAttributedString? {
        do {
            let options = getDocOptions()
            return try NSAttributedString(url: url, options: options, documentAttributes: nil)
        } catch {
            print(error.localizedDescription)
        }

        return nil
    }

    func reloadContent() {
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
            print(error.localizedDescription)
        }

        return modifiedLocalAt
    }

    func getUniqueFileName(name: String, i: Int = 0, prefix: String = "") -> URL? {
        let defaultName = "Untitled Note"

        var name = name
            .trimmingCharacters(in: CharacterSet.whitespaces)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: ":")

        if !prefix.isEmpty {
            name = name + prefix
        } else if name.isEmpty {
            name = defaultName
        }

        guard let p = project else { return nil }

        var fileUrl = p.url
        fileUrl.appendPathComponent(name)
        fileUrl.appendPathExtension(type.rawValue)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileUrl.path) {
            let j = i + 1
            let newName = defaultName + " " + String(j)
            return getUniqueFileName(name: newName, i: j, prefix: prefix)
        }

        return fileUrl
    }

    func isRTF() -> Bool {
        return (type == .RichText)
    }

    func isMarkdown() -> Bool {
        return (type == .Markdown)
    }

    func addPin() {
        sharedStorage.pinned += 1
        isPinned = true

        #if CLOUDKIT || os(iOS)
            let keyStore = NSUbiquitousKeyValueStore()
            keyStore.set(true, forKey: name)
            keyStore.synchronize()
            return
        #endif

        #if os(OSX)
            var pin = true
            let data = Data(bytes: &pin, count: 1)
            try? url.setExtendedAttribute(data: data, forName: "co.fluder.fsnotes.pin")
        #endif
    }

    func removePin() {
        if isPinned {
            sharedStorage.pinned -= 1
            isPinned = false

            #if CLOUDKIT || os(iOS)
                let keyStore = NSUbiquitousKeyValueStore()
                keyStore.set(false, forKey: name)
                keyStore.synchronize()
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
        let content = self.content.string
        return cleanMetaData(content: content)
    }

    func parseURL() {
        if (url.pathComponents.count > 0) {
            name = url.pathComponents.last!
            type = .withExt(rawValue: url.pathExtension)
            title = url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")
        }
    }

    func save(cloudSync: Bool = true) {
        syncSkipDate = Date()

        let attributes = getFileAttributes()

        do {
            guard let fileWrapper = getFileWrapper(attributedString: content) else {
                print("Wrapper not found")
                return
            }

            try fileWrapper.write(to: url, options: FileWrapper.WritingOptions.atomic, originalContentsURL: nil)

            try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        } catch {
            print("Write error \(error)")
            return
        }

        sharedStorage.add(self)
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

    func getFileWrapper(attributedString: NSAttributedString) -> FileWrapper? {
        do {
            let range = NSRange(location: 0, length: attributedString.length)
            let documentAttributes = getDocAttributes()
            let fileWrapper = try attributedString.fileWrapper(from: range, documentAttributes: documentAttributes)
            return fileWrapper
        } catch {
            return nil
        }
    }

    func isGeneral() -> Bool {
#if os(OSX)
        guard let p = project else {
            return false
        }

        return (p.label == "general")
#else
        return true
#endif
    }

    func getTitleWithoutLabel() -> String {
        return url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")
    }

    func markdownCache() {
        guard isMarkdown() else {
            return
        }

        NotesTextProcessor.fullScan(note: self, async: false)
        isCached = true
    }

    func getDocOptions() -> [NSAttributedString.DocumentReadingOptionKey: Any]  {
        if type == .RichText {
            return [.documentType : NSAttributedString.DocumentType.rtf]
        }

        return [
            .documentType : NSAttributedString.DocumentType.plain,
            .characterEncoding : NSNumber(value: String.Encoding.utf8.rawValue)
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
        guard let p = project else {
            return false
        }

        return p.isTrash
    }

    public func getCommaSeparatedTags() -> String {
        return tagNames.map { String($0) }.joined(separator: ", ")
    }

    #if os(OSX)
    public func saveTags(_ string: String) {
        var newTagsClean = [String]()
        let newTags = string.split(separator: ",")
        for newTag in newTags {
            newTagsClean.append(
                String(newTag).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

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
        for r in removed { sharedStorage.removeTag(r) }

        tagNames = newTagsClean

        try? (url as NSURL).setResourceValue(newTagsClean, forKey: .tagNamesKey)
    }

    public func addTag(_ name: String) {
        guard !tagNames.contains(name) else { return }
        tagNames.append(name)
        try? (url as NSURL).setResourceValue(tagNames, forKey: .tagNamesKey)
    }
    #endif

    public func loadTags() {
        #if os(OSX)
            let tags = try? url.resourceValues(forKeys: [.tagNamesKey])
            if let tagNames = tags?.tagNames {
                for tag in tagNames {
                    if !self.tagNames.contains(tag) {
                        self.tagNames.append(tag)
                    }
                    sharedStorage.addTag(tag)
                }
            }
        #else
            if let data = try? url.extendedAttribute(forName: "com.apple.metadata:_kMDItemUserTags"),
                let tags = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSMutableArray {
                for tag in tags {
                    if let tagName = tag as? String {
                        self.tagNames.append(tagName)
                        sharedStorage.addTag(tagName)
                    }
                }
            }
        #endif
    }
}
