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
    
/*
    func addNote(name: String) {
        let note = NSEntityDescription.entity(forEntityName: "Note", in: context)
        let options = NSManagedObject(entity: note!, insertInto: context)
        options.setValue(name, forKey: "name")
        do {
            try context.save()
        } catch {}
    }
 */
    
    func fetchNotes() -> [Note] {
        let request = NSFetchRequest<Note>(entityName: "Note")
        var results = [Note]()
        
        do {
            results = try context.fetch(request)
        } catch {
            print("Not fetched\(error)")
        }
        
        return results
    }
    
    func createNote() -> Note {
        return Note(context: context)
    }
    
    func saveContext() {
        do {
            try context.save()
        } catch {}
    }
    
}
