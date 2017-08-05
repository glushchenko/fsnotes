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
    
        if (UserDefaults.standard.object(forKey: "isUseHorizontalMode") != nil) {
            let isUseHorizontalMode = UserDefaults.standard.object(forKey: "isUseHorizontalMode") as! Bool
            
            if (isUseHorizontalMode
                && content!.hasPrefix(" – ") == false
                && content!.characters.count > 0
            ) {
                preview = " – " + content!.replacingOccurrences(of: "\n", with: " ")
            }
        }
    
        return preview
    }
}
