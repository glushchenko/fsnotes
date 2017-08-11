//
//  Note.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/30/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class Note: NSObject {
    var name: String?
    var content: String?
    var date: Date?
    var url: URL?
    
    override init(){}
    
    func make() -> Bool {
        url = getUniqueFileName(name: "Untitled Note")
        name = url?.pathComponents.last
        if save() {
            load()
            return true
        }
        return false
    }
    
    func load() {
        //print(FileManager.default.fileExists(atPath: (url?.path)!))
        content = getContent(url: url!)
        date = getDate(url: url!)
    }
    
    func rename(newName: String) {
        let fileManager = FileManager.default
        var newUrl = url?.deletingLastPathComponent()
            newUrl?.appendPathComponent(newName)
        
        do {
            try fileManager.moveItem(at: url!, to: newUrl!)
            self.url = newUrl
        }
        catch let error as NSError {
            print("Remove went wrong: \(error)")
        }
    }
    
    func remove() {
        let fileManager = FileManager.default
        
        do {
            try fileManager.trashItem(at: self.url!, resultingItemURL: nil)
        }
        catch let error as NSError {
            print("Remove went wrong: \(error)")
        }
    }
    
    func save() -> Bool {
        let fileUrl = UserDefaultsManagement.storageUrl.appendingPathComponent(name!)
        
        do {
            try content?.write(to: fileUrl, atomically: false, encoding: String.Encoding.utf8)
            
            return true
        } catch {
            print("Note write error: " + fileUrl.path)
            
            return false
        }
    }
    
    func getPreviewForLabel() -> String {
        var preview: String = ""
        
        if (UserDefaultsManagement.hidePreview) {
            return preview
        }
        
        let count: Int = (content?.characters.count)!
        
        if count > 250 {
            let startIndex = content?.index((content?.startIndex)!, offsetBy: 0)
            let endIndex = content?.index((content?.startIndex)!, offsetBy: 250)
            preview = content![startIndex!...endIndex!]
        } else {
            preview = content!
        }
        
        preview = preview.replacingOccurrences(of: "\n", with: " ")
        if (
            UserDefaultsManagement.horizontalOrientation
            && content!.hasPrefix(" – ") == false
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
        
        do {
            content = try String(contentsOf: url, encoding: String.Encoding.utf8)
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
        let defaultUrl = UserDefaultsManagement.storageUrl
        let defaultExtension = UserDefaultsManagement.storageExtension
        var fileUrl = defaultUrl
        
        fileUrl.appendPathComponent(name)
        fileUrl.appendPathExtension(defaultExtension)
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileUrl.path) {
            let j = i + 1
            let newName = "Untitled Note" + " " + String(j)
            return getUniqueFileName(name: newName, i: j)
        }
        
        return fileUrl
    }
}
