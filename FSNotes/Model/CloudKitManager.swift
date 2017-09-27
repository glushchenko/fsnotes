//
//  CloudKitManager.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/5/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitManager {
    static let instance = CloudKitManager()
    
    let identifier = "iCloud.co.fluder.fsnotes-dev"
    var container: CKContainer
    var modifiedRecords: [CKRecord]
    var database: CKDatabase
    var recordZone: CKRecordZone?
    var storage = Storage.instance
    var queryCompletionBlock: (CKQueryCursor?, Error?) -> Void = { (_,_) in }
    let modifyQueueList = [String: Note]()
    var isActiveModifyOperation: Bool = false
    
    init() {
        container = CKContainer.init(identifier: identifier)
        database = container.privateCloudDatabase
        recordZone = CKRecordZone(zoneName: "NotesZone")
        
        database.save(recordZone!, completionHandler: {(recordzone, error) in
            if (error != nil) {
                print("Zone creation error")
            }
        })
        
        modifiedRecords = []
    }
    
    func getZone() -> CKRecordZoneID {
        return CKRecordZone(zoneName: "NotesZone").zoneID
    }
    
    func sync() {
        print("Remote modified records found: \(modifiedRecords.count)")
        
        var recordNameList: [String] = []
        for record in modifiedRecords {
            do {
                let file = record.object(forKey: "file") as! CKAsset
                let recordName = record.recordID.recordName
                let fileName = recordName as NSString
                //let type = fileName.pathExtension
                let name = fileName.deletingPathExtension
                let content = try NSString(contentsOf: file.fileURL, encoding: String.Encoding.utf8.rawValue) as String
                
                recordNameList.append(name)
                
                let note = Storage.instance.getOrCreate(name: name)
                note.content = content
                note.date = record["modifiedAt"] as? Date
                note.cloudKitRecord = record.data()
                note.url = UserDefaultsManagement.storageUrl.appendingPathComponent(fileName as String)
                note.extractUrl()
                
                if (note.writeContent()) {
                    reloadView()
                }
            } catch {}
        }
        
        pushLocalChanges(exceptList: recordNameList)
    }
    
    func pushLocalChanges(exceptList: [String] = []) {
        let hostNotes = Storage.instance.getModifiedLatestThen()
        
        print("Local modified records found: \(hostNotes.count)")
        
        if hostNotes.count > 0 {
            pushNote(note: hostNotes.first!)
        } else {
            UserDefaultsManagement.lastSync = Date.init()
        }
    }
    
    func fetchNew(_ inputCursor: CKQueryCursor? = nil) {
        let operation: CKQueryOperation
        
        if let cursor = inputCursor {
            operation = CKQueryOperation(cursor: cursor)
        } else {
            let predicate = NSPredicate(format: "modifiedAt > %@", UserDefaultsManagement.lastSync as CVarArg)
            let query = CKQuery(recordType: "Note", predicate: predicate)
            operation = CKQueryOperation(query: query)
        }
        
        operation.queryCompletionBlock = { [weak self] cursor, error in
            guard error == nil else {
                Swift.print("\(error.debugDescription)")
                return
            }
            
            if let cursor = cursor {
                self?.fetchNew(cursor)
            } else {
                self?.sync()
            }
        }
        
        operation.recordFetchedBlock = {record in
            self.modifiedRecords.append(record)
        }
        
        database.add(operation)
    }
    
    func pushNote(note: Note) {
        guard note.cloudKitRecord.count == 0 else {
            Swift.print("get and save")
            self.modifyNote(note)
            return
        }
        
        let recordID = CKRecordID(recordName: note.getFileName(), zoneID: getZone())
        database.fetch(withRecordID: recordID, completionHandler: { record, error in
            if error != nil {
                let error = error as! CKError
                if error.errorCode == CKError.Code.unknownItem.rawValue {
                    self.createNote(note)
                    return
                }
            }
            
            guard let record = record else {
                return
            }
            
            note.cloudKitRecord = record.data()
            self.modifyNote(note)
        })
    }
    
    func createNote(_ note: Note) {
        let file = CKAsset(fileURL: note.url)
        let recordID = CKRecordID(recordName: note.getFileName(), zoneID: getZone())
        let record = CKRecord(recordType: "Note", recordID: recordID)
        record["file"] = file
        record["modifiedAt"] = note.date! as CKRecordValue
        
        database.save(record) {
            (record, error) in
            if error != nil {
                print("Save error \(error.debugDescription)")
                return
            }
            
            guard let record = record else {
                return
            }
            
            note.cloudKitRecord = record.data()
            note.isSynced = true
            CoreDataManager.instance.saveContext()
            
            print("Successfully saved: \(note.getFileName())")
        }
    }
    
    func modifyNote(_ note: Note) {
        if isActiveModifyOperation {
            return
        }
        
        isActiveModifyOperation = true
        
        if note.cloudKitRecord.count == 0 {
            return
        }
        
        let record = CKRecord(archivedData: note.cloudKitRecord)!
        let file = CKAsset(fileURL: note.url)
        
        record["file"] = file
        record["modifiedAt"] = note.date! as CKRecordValue
        
        let modifyRecords = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: [])
        modifyRecords.savePolicy = CKRecordSavePolicy.allKeys
        modifyRecords.qualityOfService = QualityOfService.userInitiated
        modifyRecords.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            self.isActiveModifyOperation = false
            self.pushLocalChanges()
            
            guard let error = error as? CKError else {
                note.cloudKitRecord = savedRecords![0].data()
                note.isSynced = true
                CoreDataManager.instance.saveContext()
                
                print("Successfully modified: \(note.getFileName())")
                return
            }
            print("Error: \(error.localizedDescription), note: \(note.getFileName())")
        }
        
        self.database.add(modifyRecords)
    }
    
    func reloadView() {
        DispatchQueue.main.async() {
            let viewController = NSApplication.shared().windows.first!.contentViewController as! ViewController
            viewController.updateTable(filter: "")
        }
    }
    
}
