//
//  CoreDataManager.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/23/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import CoreData
import Cocoa

class CoreDataManager {
    static let instance = CoreDataManager()
    private static var defaultStorage: StorageItem? = nil
    
    var context: NSManagedObjectContext
    
    init() {
        let appDel: AppDelegate = (NSApplication.shared.delegate as! AppDelegate)
        context = appDel.persistentContainer.viewContext
        context.mergePolicy = NSOverwriteMergePolicy
    }
    
    func make() -> Note {
        return Note(context: context)
    }
    
    func fetchAll() -> [Note] {
        let request = NSFetchRequest<Note>(entityName: "Note")
        var results = [Note]()
        
        do {
            results = try context.fetch(request)
        } catch {
            print("Not fetched \(error)")
        }
        
        return results
    }
    
    func save() {
        do {
            try context.save()
        } catch {
            print("Save error \(error)")
        }
    }
    
    func remove(_ note: Note) {
        do {
            context.delete(note)
            try context.save()
        } catch {
            print("Remove error \(error)")
        }
    }
    
    func remove(storage: StorageItem) {
        do {
            context.delete(storage)
            try context.save()
        } catch {
            print("Remove error \(error)")
        }
    }
    
    func getBy(url: URL) -> Note? {
        guard let storageItem = fetchStorageItemBy(fileUrl: url) else {
            return nil
        }

        let name = url.pathComponents.last!
        let request = NSFetchRequest<Note>(entityName: "Note")
        let predicate = NSPredicate(format: "name = %@ AND storage = %@", argumentArray: [name, storageItem])
        
        request.predicate = predicate
        do {
            return try context.fetch(request).first
        } catch {
            print("Not fetched \(error)")
        }
        return nil
    }
    
    func removeCloudKitRecords() {
        let batchUpdateRequest = NSBatchUpdateRequest(entityName: "Note")
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        batchUpdateRequest.propertiesToUpdate = ["cloudKitRecord": Data(), "isSynced": false]
        
        do {
            try context.execute(batchUpdateRequest)
        } catch {
            let updateError = error as NSError
            print("\(updateError), \(updateError.userInfo)")
        }
    }
    
    func getBy(label: String) -> StorageItem? {
        let request = NSFetchRequest<StorageItem>(entityName: "StorageItem")
        let predicate = NSPredicate(format: "label = %@", label)
        request.predicate = predicate
        do {
            let storage = try context.fetch(request)
            if !storage.isEmpty {
                return storage.first
            }
            return nil
        } catch {
            print("Not fetched \(error)")
        }
        return nil
    }
    
    func fetchStorageList() -> [StorageItem] {
        let request = NSFetchRequest<StorageItem>(entityName: "StorageItem")
        var results = [StorageItem]()
        
        do {
            results = try context.fetch(request)
        } catch {
            print("Not fetched \(error)")
        }
        
        return results
    }
    
    func fetchStorageItemBy(fileUrl: URL) -> StorageItem? {
        let path = fileUrl.deletingLastPathComponent().absoluteString
        let request = NSFetchRequest<StorageItem>(entityName: "StorageItem")
        let predicate = NSPredicate(format: "path = %@", path)
        request.predicate = predicate
        do {
            return try context.fetch(request).first
        } catch {
            print("Not fetched \(error)")
        }
        return nil
    }
    
    func fetchGeneralStorage() -> StorageItem? {
        if let storage = CoreDataManager.defaultStorage {
            return storage
        }
        
        let request = NSFetchRequest<StorageItem>(entityName: "StorageItem")
        request.predicate = NSPredicate(format: "label = %@", "general")
        do {
            let item = try context.fetch(request).first
            CoreDataManager.defaultStorage = item
            return item
        } catch {
            print("General storage not found \(error)")
        }
        return nil
    }
    
}
