//
//  CoreDataManager.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/23/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class CoreDataManager {
    static let instance = CoreDataManager()
    let context: NSManagedObjectContext
    
    init() {
        let appDel: AppDelegate = (NSApplication.shared.delegate as! AppDelegate)
        context = appDel.persistentContainer.viewContext
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
        let storageItem = fetchStorageItemBy(fileUrl: url)
        let name = url.pathComponents.last!
        
        let request = NSFetchRequest<Note>(entityName: "Note")
        let predicate = NSPredicate(format: "name = %@ AND storage = %@", argumentArray: [name, storageItem!])
        
        request.predicate = predicate
        do {
            return try context.fetch(request).first
        } catch {
            print("Not fetched \(error)")
        }
        return nil
    }
    
    func removeCloudKitRecords() {
        let entityDescription = NSEntityDescription.entity(forEntityName: "Note", in: context)
        let batchUpdateRequest = NSBatchUpdateRequest(entity: entityDescription!)
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        batchUpdateRequest.propertiesToUpdate = ["cloudKitRecord": Data(), "isSynced": false]
        
        do {
            let batchUpdateResult = try context.execute(batchUpdateRequest) as! NSBatchUpdateResult
            let objectIDs = batchUpdateResult.result as! [NSManagedObjectID]
            for objectID in objectIDs {
                let managedObject = context.object(with: objectID)
                context.refresh(managedObject, mergeChanges: false)
            }
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
            return try context.fetch(request).first
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
    
}
