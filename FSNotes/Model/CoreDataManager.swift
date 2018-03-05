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
    
    func removeNotes(notes: [Note], fsRemove: Bool = true) {
        if fsRemove {
            for note in notes {
                note.removeFile()
            }
        }
        
        for note in notes {
            context.delete(note)
        }
        
        do {
            try context.save()
        } catch {
            print("Notes remove error \(error)")
        }
    }
    
    func setDefaultStorage(storage: StorageItem) {
        CoreDataManager.defaultStorage = storage
    }
}
