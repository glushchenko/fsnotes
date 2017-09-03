//
//  Note.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/30/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Cocoa

class Note: NSObject {
    var id: Int = 0
    var name: String = ""
    var type: String = "md"
    var content: String = ""
    var date: Date?
    var url: URL!
    var isRemoved: Bool = false
    var isPinned: Bool = false
        
    override init(){}
    
    func make(id: Int, newName: String) {
        url = getUniqueFileName(name: newName)
        name = (url.deletingPathExtension().pathComponents.last)!
        date = Date.init()
        self.id = id
    }

    func load() {
        content = getContent(url: url)
        date = getDate(url: url)
    }
    
    func rename(newName: String) -> Bool {
        let fileManager = FileManager.default
        var newUrl = url.deletingLastPathComponent()
            newUrl.appendPathComponent(newName + "." + type)
        
        do {
            try fileManager.moveItem(at: url, to: newUrl)
            url = newUrl
            return true
        } catch {
            name = (url.deletingPathExtension().pathComponents.last)!
            return false
        }
    }
    
    func remove() {
        isRemoved = true
        let fileManager = FileManager.default
        
        do {
            try fileManager.trashItem(at: self.url, resultingItemURL: nil)
            
            if (isPinned) {
                removePin()
            }
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
        
        return preview
    }
    
    func getDateForLabel() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yy"
        
        return dateFormatter.string(from: self.date!)
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
    
    func getDate(url: URL) -> Date {
        var modificationDate: Date?
        
        do {
            let fileAttribute: [FileAttributeKey : Any] = try FileManager.default.attributesOfItem(atPath: url.path)
            
            modificationDate = fileAttribute[FileAttributeKey.modificationDate] as? Date
        } catch {
            print(error.localizedDescription)
        }
        
        return modificationDate!
    }
    
    func getUniqueFileName(name: String, i: Int = 0) -> URL {
        let defaultName = "Untitled Note"
        let defaultUrl = UserDefaultsManagement.storageUrl
        let defaultExtension = UserDefaultsManagement.storageExtension
        
        var name = name.trimmingCharacters(in: CharacterSet.whitespaces)
        if (name.characters.count == 0) {
            name = defaultName
        }
        
        var fileUrl = defaultUrl
        fileUrl.appendPathComponent(name)
        fileUrl.appendPathExtension(defaultExtension)
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileUrl.path) {
            let j = i + 1
            let newName = defaultName + " " + String(j)
            return getUniqueFileName(name: newName, i: j)
        }
        
        return fileUrl
    }
    
    func isRTF() -> Bool {        
        return (url.pathExtension == "rtf")
    }
    
    func addPin() {
        let urlString = url.absoluteString
        var pinnedNotes = UserDefaultsManagement.pinnedNotes
        pinnedNotes.append(urlString)
        UserDefaultsManagement.pinnedNotes = pinnedNotes
        Storage.pinned += 1
        
        isPinned = true
    }
    
    func removePin() {
        let urlString = url.absoluteString
        var pinnedNotes = UserDefaultsManagement.pinnedNotes
        
        if let itemToRemoveIndex = pinnedNotes.index(of: urlString) {
            pinnedNotes.remove(at: itemToRemoveIndex)
            UserDefaultsManagement.pinnedNotes = pinnedNotes
            Storage.pinned -= 1
        }
        
        isPinned = false
    }
    
    func togglePin() {
        if (!isPinned) {
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
}
