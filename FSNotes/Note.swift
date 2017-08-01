//
//  Note.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/30/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class Note {
    var name: String?
    var content: String?
    var date: Date?
    var url: URL?
    
    func remove() {
        let fileManager = FileManager.default
        
        do {
            try fileManager.removeItem(at: self.url!)
        }
        catch let error as NSError {
            print("Remove went wrong: \(error)")
        }
    }
}
