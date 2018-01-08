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
import Cocoa

@objc(Note)
public class Note: NSManagedObject {
    var type: NoteType = .Markdown
    var url: URL!
    @objc var title: String = ""
    var content: NSMutableAttributedString = NSMutableAttributedString()
    
    var syncSkipDate: Date?
    var syncDate: Date?
    var creationDate: Date? = Date()
        
    func make(newName: String) {
        url = getUniqueFileName(name: newName)
        parseURL()
    }
    
    func load(_ newUrl: URL) {
        url = newUrl
        type = NoteType.withExt(rawValue: url.pathExtension)
        parseURL()
        
        if let attributedString = getContent() {
            content = NSMutableAttributedString(attributedString: attributedString)
        }
    }
    
    func initWith(url: URL, fileName: String) {
        storage = CoreDataManager.instance.fetchGeneralStorage()
        
        self.url = Storage.instance.getBaseURL().appendingPathComponent(fileName)
        parseURL()
        
        let options = getDocOptions()
        
        do {
            self.content = try NSMutableAttributedString(url: url, options: options, documentAttributes: nil)
            markdownCache()
        } catch {
            print("Document \"\(fileName)\" not loaded. Error: \(error)")
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
    
    func rename(newName: String) -> Bool {
        let escapedName = newName
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: ":")
    
        let fileManager = FileManager.default
        var newUrl = url.deletingLastPathComponent()
        newUrl.appendPathComponent(escapedName + "." + url.pathExtension)
        
        do {
            try fileManager.moveItem(at: url, to: newUrl)
            url = newUrl
            parseURL()
            CoreDataManager.instance.save()
            return true
        } catch {
            parseURL()
            return false
        }
    }
    
    func remove() {
        let fileManager = FileManager.default
        let removeName = name
        
        do {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
            
            if let position = Storage.instance.noteList.index(of: self) {
                Storage.instance.noteList.remove(at: position)
                
                cloudRemove(name: removeName)
            }
            
        } catch let error as NSError {
            print("Remove went wrong: \(error)")
            return
        }
    }
    
    func cloudRemove(name: String) {
        #if CLOUDKIT
            if UserDefaultsManagement.cloudKitSync {
                isRemoved = true
                CloudKitManager.instance.removeRecord(note: self)
            }
        #else
            CoreDataManager.instance.remove(self)
            print("Removed successfully: \(name)")
        #endif
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = DateFormatter.Style.short
        dateFormatter.timeStyle = DateFormatter.Style.none
        dateFormatter.locale = NSLocale.autoupdatingCurrent
        
        return dateFormatter.string(from: self.modifiedLocalAt!)
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
    
    func getDate(url: URL) -> Date? {
        var modifiedLocalAt: Date?
        
        do {
            let fileAttribute: [FileAttributeKey : Any] = try FileManager.default.attributesOfItem(atPath: url.path)
            
            modifiedLocalAt = fileAttribute[FileAttributeKey.modificationDate] as? Date
        } catch {
            print(error.localizedDescription)
        }
        
        return modifiedLocalAt
    }
    
    func getUniqueFileName(name: String, i: Int = 0, prefix: String = "") -> URL {
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
    
        var fileUrl = Storage.instance.getBaseURL()
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
        Storage.pinned += 1
        isPinned = true
        CoreDataManager.instance.save()
    }
    
    func removePin() {
        if isPinned {
            Storage.pinned -= 1
            isPinned = false
        }
    }
    
    func togglePin() {
        if !isPinned {
            addPin()
        } else {
            removePin()
            CoreDataManager.instance.save()
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
            
            var titleName = url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")
            
            if let storageUnwrapped = storage, let label = storageUnwrapped.label, label != "general" {
                let trimmedLabel = label.trim()
                
                if !trimmedLabel.isEmpty {
                    titleName = trimmedLabel + " / " + titleName
                }
            }
            
            title = titleName
        }
    }
    
    func writeContent() -> Bool {
        do {
            try content.string.write(to: url, atomically: false, encoding: String.Encoding.utf8)
            return true
        } catch {
            return false
        }
    }
    
    func save(_ textStorage: NSTextStorage = NSTextStorage(), userInitiated: Bool = false) {
        syncSkipDate = Date()
       
        do {
            let range = NSRange(location: 0, length: textStorage.length)
            let documentAttributes = getDocAttributes()
            let text = try textStorage.fileWrapper(from: range, documentAttributes: documentAttributes)
            try text.write(to: url, options: FileWrapper.WritingOptions.atomic, originalContentsURL: nil)
        } catch let error {
            print("Core data: \(error.localizedDescription)")
            return
        }
        
        cloudSave(userInitiated: userInitiated)
    }
    
    func cloudSave(userInitiated: Bool = false) {
        if !Storage.instance.noteList.contains(where: { $0.name == name && $0.storage == storage }) {
            Storage.instance.add(self)
        }
        
        loadModifiedLocalAt()
        
        #if CLOUDKIT
            if UserDefaultsManagement.cloudKitSync {
                if userInitiated {
                    NotificationsController.onStartSync()
                }
                
                // save state to core database
                isSynced = false
                CoreDataManager.instance.save()
                
                // save cloudkit
                CloudKitManager.instance.saveNote(self)
            }
        #endif
    }
        
    func checkLocalSyncState(_ currentDate: Date) {        
        if currentDate != modifiedLocalAt {
            isSynced = false
        }
    }
    
    func isGeneral() -> Bool {
        guard let storageItem = storage else {
            return false
        }
        
        guard let label = storageItem.label else {
            return false
        }
        
        return (label == "general")
    }
    
    func getTitleWithoutLabel() -> String {
        return url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")
    }
    
    func markdownCache() {
        guard isMarkdown() else {
            return
        }
        
        NotesTextProcessor.fullScan(note: self, async: false)
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
}
