//
//  Project.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class Project: Equatable {
    var url: URL
    var label: String?
    var isTrash: Bool
    
    init(url: URL, label: String? = nil, isTrash: Bool = false) {
        self.url = url
        self.isTrash = isTrash
        
        if let l = label {
            self.label = l
        }
    }
    
    func fileExist(fileName: String, ext: String) -> Bool {        
        let fileURL = url.appendingPathComponent(fileName + "." + ext)
        
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.url == rhs.url
    }
}
