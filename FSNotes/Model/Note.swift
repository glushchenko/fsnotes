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
            try fileManager.removeItem(at: self.url!)
        }
        catch let error as NSError {
            print("Remove went wrong: \(error)")
        }
    }
    
    func getPreviewForLabel() -> String {
        var preview: String = content!
    
        let isUseHorizontalMode = UserDefaults.standard.object(forKey: "isUseHorizontalMode")
        
        if (isUseHorizontalMode != nil) {
            if (isUseHorizontalMode as! Bool
                && content!.hasPrefix(" – ") == false
                && content!.characters.count > 0
            ) {
                preview = " – " + content!.replacingOccurrences(of: "\n", with: " ")
            }
        }
    
        return preview
    }
    
    func getDateForLabel() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yy"
        return dateFormatter.string(from: self.date!)
    }
}
