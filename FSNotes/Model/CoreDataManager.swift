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
        let appDel: AppDelegate = (NSApplication.shared().delegate as! AppDelegate)
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
            print("Note removed \(note.name)")
        } catch {
            print("Remove error \(error)")
        }
    }
    
    func getBy(_ url: URL) -> Note? {
        let name = url.pathComponents.last!
        let request = NSFetchRequest<Note>(entityName: "Note")
        let predicate = NSPredicate(format: "name = %@", name)
        request.predicate = predicate
        do {
            return try context.fetch(request).first
        } catch {
            print("Not fetched \(error)")
        }
        return nil
    }
    
}
