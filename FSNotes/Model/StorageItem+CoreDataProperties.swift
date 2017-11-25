//
//  StorageItem+CoreDataProperties.swift
//  
//
//  Created by Oleksandr Glushchenko on 11/21/17.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData

extension StorageItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StorageItem> {
        return NSFetchRequest<StorageItem>(entityName: "StorageItem")
    }

    @NSManaged public var label: String?
    @NSManaged public var path: String?
    @NSManaged public var note: Note?

}
