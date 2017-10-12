//
//  CloudKitManager.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 9/5/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import CloudKit

enum CloudKitResult {
    case success(CKRecord)
    case failure(String)
}

class CloudKitManager {
    static let instance = CloudKitManager()
    
    let identifier = "iCloud.co.fluder.fsnotes-dev"
    let zone = "NotesZone"
    
    var container: CKContainer
    var modifiedRecords: [CKRecord] = []
    var database: CKDatabase
    var recordZone: CKRecordZone?
    var storage = Storage.instance
    var queryCompletionBlock: (CKQueryCursor?, Error?) -> Void = { (_,_) in }
    let modifyQueueList = [String: Note]()
    var hasActivePushConnection: Bool = false
    
    init() {
        container = CKContainer.init(identifier: identifier)
        database = container.privateCloudDatabase
        recordZone = CKRecordZone(zoneName: zone)
        
        database.save(recordZone!, completionHandler: {(recordzone, error) in
            if (error != nil) {
                print("Zone creation error")
            }
        })
    }
    
    func getZone() -> CKRecordZoneID {
        return CKRecordZone(zoneName: "NotesZone").zoneID
    }
    
    func sync() {
        push()
        pull()
    }
    
    func pull() {
        var recordNameList: [String] = []
        for record in modifiedRecords {
            do {
                let file = record.object(forKey: "file") as! CKAsset
                let recordName = record.recordID.recordName
                let fileName = recordName as String
                let content = try NSString(contentsOf: file.fileURL, encoding: String.Encoding.utf8.rawValue) as String
                
                recordNameList.append(fileName)
                
                let note = Storage.instance.getOrCreate(name: fileName)
                if (note.modifiedLocalAt == record["modifiedAt"] as! Date) {
                    continue
                }
                
                note.content = content
                note.cloudKitRecord = record.data()
                note.url = UserDefaultsManagement.storageUrl.appendingPathComponent(fileName)
                note.extractUrl()
                
                if (note.writeContent()) {
                    note.loadModifiedLocalAt()
                    reloadView()
                }
                
                print("Note downloaded: \(note.name)")
            } catch {}
        }
        
        UserDefaultsManagement.lastSync = Date.init()
    }
    
    func push() {
        guard let note = Storage.instance.getModified() else {
            return
        }
        
        getRecord(note: note, completion: { result in
            print("Local modified record found: \(note.getFileName())")
            self.saveNote(note)
        })
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
    
    func saveNote(_ note: Note) {
        var record: CKRecord
        
        if (note.cloudKitRecord.isEmpty) {
            record = createRecord(note)
        } else {
            record = CKRecord(archivedData: note.cloudKitRecord)!
            record = fillRecord(note: note, record: record)
        }
        
        saveRecord(note: note, sRecord: record)
    }
    
    func saveRecord(note: Note, sRecord: CKRecord) {
        if !hasActivePushConnection {
            hasActivePushConnection = true
            
            database.save(sRecord) { (record, error) in
                self.hasActivePushConnection = false
                
                guard error == nil else {
                    NSLog("Save error \(error.debugDescription)")
                    return
                }
                
                guard let record = record else {
                    NSLog("Record not found")
                    return
                }
                
                note.cloudKitRecord = record.data()
                if (note.modifiedLocalAt == record["modifiedAt"] as! Date) {
                    note.isSynced = true
                }
                
                CoreDataManager.instance.save()
                print("Successfully saved: \(note.getFileName())")
                self.push()
            }
        }
    }
    
    func removeRecord(note: Note) {
        getRecord(note: note, completion: { result in
            switch result {
            case .success(let record):
                self.database.delete(withRecordID: record.recordID, completionHandler: { record, error in
                    CoreDataManager.instance.remove(note)
                    print("Success removed note \(note.name)")
                })
            case .failure(let error):
                print("Remove cloud kit error \(error)")
            }
        })
    }
 
    func getRecord(note: Note, completion: @escaping (CloudKitResult) -> Void) {
        if (!note.cloudKitRecord.isEmpty) {
            let record = CKRecord(archivedData: note.cloudKitRecord)
            completion(.success(record!))
            return
        }
        
        let recordID = CKRecordID(recordName: note.getFileName(), zoneID: getZone())
        database.fetch(withRecordID: recordID, completionHandler: { record, error in
            if error != nil {
                completion(.failure("Fetch error \(error!.localizedDescription)"))
                return
            }
            
            completion(.success(record!))
        })
    }
    
    func createRecord(_ note: Note) -> CKRecord {
        let recordID = CKRecordID(recordName: note.getFileName(), zoneID: getZone())
        let record = CKRecord(recordType: "Note", recordID: recordID)
        return fillRecord(note: note, record: record)
    }
    
    func fillRecord(note: Note, record: CKRecord) -> CKRecord{
        record["file"] = CKAsset(fileURL: note.url)
        record["modifiedAt"] = note.modifiedLocalAt as! CKRecordValue
        return record
    }
    
    func reloadView() {
        DispatchQueue.main.async() {
            let viewController = NSApplication.shared().windows.first!.contentViewController as! ViewController
            viewController.updateTable(filter: "")
        }
    }
    
    func fetchChanges(completion: @escaping ([CKRecord], [CKRecordID], CKServerChangeToken?) -> Void) {
        let zonedId = getZone()
        let options = CKFetchRecordZoneChangesOptions()
        options.previousServerChangeToken = UserDefaults.standard.serverChangeToken
    
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zonedId], optionsByRecordZoneID: [zonedId: options])
        
        var changedRecords: [CKRecord] = []
        operation.recordChangedBlock = { (record: CKRecord) in
            changedRecords.append(record)
        }
        
        var deletedRecordIDs: [CKRecordID] = []
        operation.recordWithIDWasDeletedBlock = { (recordID: CKRecordID, identifier: String) in
            deletedRecordIDs.append(recordID)
        }
        
        var serverChangesToken: CKServerChangeToken?
        operation.recordZoneFetchCompletionBlock = { (zoneID: CKRecordZoneID, token: CKServerChangeToken?, _: Data?, _: Bool, _: Error?) in
            if (token != UserDefaults.standard.serverChangeToken) {
                print("Record zone has changes!")
                serverChangesToken = token
            }
        }
        
        operation.fetchRecordZoneChangesCompletionBlock = { (error: Error?) in
            completion(changedRecords, deletedRecordIDs, serverChangesToken)
        }
        
        database.add(operation)
    }
}
