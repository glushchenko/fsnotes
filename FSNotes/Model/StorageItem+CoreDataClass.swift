//
//  StorageItem+CoreDataClass.swift
//  
//
//  Created by Oleksandr Glushchenko on 11/21/17.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData

@objc(StorageItem)
public class StorageItem: NSManagedObject {
    func getUrl() -> URL? {
        if let pathUnwrapped = path {
            return URL(string: pathUnwrapped)
        }
        return nil
    }
    
    @objc func getPath() -> String? {
        if let url = getUrl() {
            return url.path.replacingOccurrences(of: "file://", with: "")
        }
        return nil
    }
    
    func fileExist(fileName: String, ext: String) -> Bool {
        guard let url = getUrl() else {
            return false
        }
        
        let fileURL = url.appendingPathComponent(fileName + "." + ext)
    
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
