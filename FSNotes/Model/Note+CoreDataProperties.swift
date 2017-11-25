//
//  NoteMO+CoreDataProperties.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/24/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//
//

import Foundation
import CoreData


extension Note {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note")
    }

    @NSManaged public var name: String
    @NSManaged public var isPinned: Bool
    @NSManaged public var isSynced: Bool
    @NSManaged public var isRemoved: Bool
    @NSManaged public var cloudKitRecord: Data
    @NSManaged public var modifiedLocalAt: Date?
    @NSManaged public var storage: StorageItem?

}
