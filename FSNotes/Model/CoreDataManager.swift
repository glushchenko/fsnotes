//
//  CoreDataManager.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/23/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import CoreData

class CoreDataManager {
    static let instance = CoreDataManager()
    private static var defaultStorage: StorageItem? = nil
    
    var context: NSManagedObjectContext
    
    init() {
        let container = NSPersistentContainer(name: "FSNotes")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
        })
        
        context = container.viewContext
        context.mergePolicy = NSOverwriteMergePolicy
    }
    
    func entityForName(entityName: String) -> NSEntityDescription {
        return NSEntityDescription.entity(forEntityName: entityName, in: self.context)!
    }
        
    func save() {
        do {
            try context.save()
        } catch {
            print("Save error \(error)")
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
    
    func setDefaultStorage(storage: StorageItem) {
        CoreDataManager.defaultStorage = storage
    }
}
