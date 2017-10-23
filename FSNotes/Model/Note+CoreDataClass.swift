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

@objc(Note)
public class Note: NSManagedObject {
    var type: String = "md"
    var url: URL!
    var title: String = ""
    var content: String = ""
        
    func make(id: Int, newName: String) {
        url = getUniqueFileName(name: newName)
        extractUrl()
    }
    
    func load(_ newUrl: URL) {
        url = newUrl
        content = getContent(url: url)
        extractUrl()
        loadModifiedLocalAt()
    }
    
    func reload() -> Bool {
        guard let modifiedAt = getFileModifiedDate() else {
            return false
        }
        
        guard let prevModifiedAt = modifiedLocalAt else {
            return false
        }
                
        if (modifiedAt != prevModifiedAt) {
            content = getContent(url: url)
            loadModifiedLocalAt()
            return true
        }
        
        return false
    }
    
    func loadModifiedLocalAt() {
        guard let modifiedAt = getFileModifiedDate() else {
            return
        }

        modifiedLocalAt = modifiedAt
    }
    
    func getFileModifiedDate() -> Date? {
        do {
            return (try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)!
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
        newUrl.appendPathComponent(escapedName + "." + type)
        
        do {
            try fileManager.moveItem(at: url, to: newUrl)
            url = newUrl
            extractUrl()
            CoreDataManager.instance.save()
            return true
        } catch {
            extractUrl()
            return false
        }
    }
    
    func remove() {
        let fileManager = FileManager.default
        
        do {
            try fileManager.trashItem(at: self.url, resultingItemURL: nil)
            
        #if CLOUDKIT
            isRemoved = true
            CoreDataManager.instance.save()
            CloudKitManager.instance.removeRecord(note: self)
        #else
            CoreDataManager.instance.remove(self)
        #endif
        }
        catch let error as NSError {
            print("Remove went wrong: \(error)")
        }
    }
    
    func getPreviewForLabel() -> String {
        var preview: String = ""
        
        if (UserDefaultsManagement.hidePreview) {
            return preview
        }
        
        let count: Int = (content.characters.count)
        
        if count > 250 {
            let startIndex = content.index((content.startIndex), offsetBy: 0)
            let endIndex = content.index((content.startIndex), offsetBy: 250)
            preview = content[startIndex...endIndex]
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
    
    func getDateForLabel() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = DateFormatter.Style.short
        dateFormatter.timeStyle = DateFormatter.Style.none
        dateFormatter.locale = NSLocale(localeIdentifier: Locale.preferredLanguages[0]) as Locale!
        
        return dateFormatter.string(from: self.modifiedLocalAt!)
    }
    
    func getContent(url: URL) -> String {
        var content: String = ""
        let attributes = DocumentAttributes.getDocumentAttributes(fileExtension: url.pathExtension)
        
        do {
            let attributedString = try NSAttributedString(url: url, options: attributes, documentAttributes: nil)
            
            content = NSTextStorage(attributedString: attributedString).string
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        return content
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
        let defaultUrl = UserDefaultsManagement.storageUrl
        let defaultExtension = UserDefaultsManagement.storageExtension
        
        var name = name
            .trimmingCharacters(in: CharacterSet.whitespaces)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: ":")

        if prefix.characters.count > 0 {
            name = name + prefix
        } else if (name.characters.count == 0) {
            name = defaultName
        }
    
        var fileUrl = defaultUrl
        fileUrl.appendPathComponent(name)
        fileUrl.appendPathExtension(defaultExtension)
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileUrl.path) {
            let j = i + 1
            let newName = defaultName + " " + String(j)
            return getUniqueFileName(name: newName, i: j, prefix: prefix)
        }
        
        return fileUrl
    }
    
    func isRTF() -> Bool {
        return (url.pathExtension == "rtf")
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
                    let matches = regex.matches(in: String(nsHeader), options: [], range: NSMakeRange(0, (nsHeader as String).characters.count))
                    
                    if let match = matches.first {
                        let range = match.rangeAt(1)
                        extractedTitle = nsHeader.substring(with: range)
                        break
                    }
                }
                
                if (extractedTitle.characters.count > 0) {
                    list.removeSubrange(Range(0...1))
                    
                    return "## " + extractedTitle + "\n\n" + list.joined()
                }
                
                return list.joined()
            }
        }
        
        return content
    }
    
    func getPrettifiedContent() -> String {
        let content = self.content
        return cleanMetaData(content: content)
    }
    
    func extractUrl() {
        if (url.pathComponents.count > 0) {
            type = url.pathExtension
            name = url.pathComponents.last!
            title = url.deletingPathExtension().pathComponents.last!.replacingOccurrences(of: ":", with: "/")
        }
    }
    
    func writeContent() -> Bool {
        do {
            try content.write(to: url!, atomically: false, encoding: String.Encoding.utf8)
            return true
        } catch {
            return false
        }
    }
    
    func save(_ textStorage: NSTextStorage = NSTextStorage()) {
        
        // save plain text file content
        do {
            let range = NSRange(location: 0, length: textStorage.string.characters.count)
            let documentAttributes = DocumentAttributes.getDocumentAttributes(fileExtension: type)
            let text = try textStorage.fileWrapper(from: range, documentAttributes: documentAttributes)
            try text.write(to: url, options: FileWrapper.WritingOptions.atomic, originalContentsURL: nil)
        } catch let error {
            NSLog(error.localizedDescription)
        }
        
        if !Storage.instance.noteList.contains(where: { $0.name == name }) {
            Storage.instance.add(self)
        }
        
        loadModifiedLocalAt()
        
        #if CLOUDKIT
            // save state to core database
            isSynced = false
            CoreDataManager.instance.save()
            
            // save cloudkit
            CloudKitManager.instance.saveNote(self)
        #endif
    }
        
    func checkLocalSyncState(_ currentDate: Date) {        
        if currentDate != modifiedLocalAt {
            isSynced = false
        }
    }
}
