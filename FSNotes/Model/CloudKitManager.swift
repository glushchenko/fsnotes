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
    
    let identifier = "iCloud.co.fluder.fsnotes"
    let zone = "NotesZone"
    
    var container: CKContainer
    var modifiedRecords: [CKRecord] = []
    var database: CKDatabase
    var recordZone: CKRecordZone?
    var storage = Storage.instance
    var queryCompletionBlock: (CKQueryCursor?, Error?) -> Void = { (_,_) in }
    let modifyQueueList = [String: Note]()
    var hasActivePushConnection: Bool = false
    
    let publicDataSubscriptionID = "cloudKitCreateUpdateDeleteSubscription"
    
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
        fetchChanges() {modifiedRecords, deletedRecords, token in
            for record in modifiedRecords {
                do {
                    let file = record.object(forKey: "file") as! CKAsset
                    let recordName = record.recordID.recordName
                    let fileName = recordName as String
                    let content = try NSString(contentsOf: file.fileURL, encoding: String.Encoding.utf8.rawValue) as String
                    
                    let note = Storage.instance.getOrCreate(name: fileName)
                    if (note.modifiedLocalAt == record["modifiedAt"] as? Date) {
                        continue
                    }
                    
                    note.content = content
                    note.cloudKitRecord = record.data()
                    note.url = UserDefaultsManagement.storageUrl.appendingPathComponent(fileName)
                    note.extractUrl()
                    
                    if (note.writeContent()) {
                        note.loadModifiedLocalAt()
                        self.reloadView(note: note)
                    }
                    
                    print("Note downloaded: \(note.name)")
                } catch {}
            }
            
            if token != nil {
                UserDefaults.standard.serverChangeToken = token
            }
        }
    }
    
    func push() {
        guard let note = Storage.instance.getModified() else {
            return
        }
        
        getRecord(note: note, completion: { result in
            self.saveNote(note)
        })
    }
    
    func saveNote(_ note: Note) {
        guard !hasActivePushConnection && note.name.characters.count > 0 else {
            return
        }

        hasActivePushConnection = true
        var record: CKRecord? = nil
        
        if note.cloudKitRecord.isEmpty {
            record = createRecord(note)
        } else {
            record = CKRecord(archivedData: note.cloudKitRecord)!
            if let unwrappedRecord = record {
                record = fillRecord(note: note, record: unwrappedRecord)
            }
        }
        
        guard let unwrappedRecord = record else {
            hasActivePushConnection = false
            return
        }
        
        saveRecord(note: note, sRecord: unwrappedRecord)
    }
    
    func saveRecord(note: Note, sRecord: CKRecord) {
        database.save(sRecord) { (record, error) in
            self.hasActivePushConnection = false
            
            guard error == nil else {
                if error?._code == CKError.serverRecordChanged.rawValue {
                    print("Server record changed. Need resolve conflict.")
                    self.resolveConflict(note: note, sRecord: sRecord)
                    return
                }
                
                if error?._code == CKError.assetFileModified.rawValue {
                    self.saveNote(note)
                    return
                }
                
                if error?._code == CKError.unknownItem.rawValue {
                    note.cloudKitRecord = Data()
                    self.saveRecord(note: note, sRecord: sRecord)
                    return
                }
                
                print("Save \(note.name) error \(error.debugDescription)")
                return
            }
            
            self.updateNoteRecord(note: note, record: record)
            self.push()
        }
    }
    
    func resolveConflict(note: Note, sRecord: CKRecord) {
        self.fetchRecord(recordName: note.name, completion: { result in
            switch result {
            case .success(let fetchedRecord):
                do {
                    let file = fetchedRecord.object(forKey: "file") as! CKAsset
                    let content = try NSString(contentsOf: file.fileURL, encoding: String.Encoding.utf8.rawValue) as String
                    
                    self.updateNoteRecord(note: note, record: fetchedRecord)
                    
                    let newNote = CoreDataManager.instance.make()
                    let date = fetchedRecord.object(forKey: "modifiedAt") as! Date
                    let dateFormatter = ISO8601DateFormatter()
                    let dateString: String = dateFormatter.string(from: date)
                    newNote.url = newNote.getUniqueFileName(name: note.title, prefix: " (CONFLICT " + dateString + ")")
                    newNote.extractUrl()
                    newNote.content = content
                    print("Resolve conflict started")
                    if newNote.writeContent() {
                        self.saveRecord(note: note, sRecord: fetchedRecord)
                    }
                } catch {}
                
            case .failure(let error):
                print("Fetch failure \(error)")
            }
        })
    }
    
    func updateNoteRecord(note: Note, record: CKRecord?) {
        guard let record = record else {
            print("Record not found")
            return
        }
        
        print("Successfully saved: \(note.name)")
        
        note.cloudKitRecord = record.data()
        if note.modifiedLocalAt == record["modifiedAt"] as? Date  {
            note.isSynced = true
        }
        
        CoreDataManager.instance.save()
    }
    
    func removeRecord(note: Note) {
        getRecord(note: note, completion: { result in
            switch result {
            case .success(let record):
                self.database.delete(withRecordID: record.recordID, completionHandler: { record, error in
                    CoreDataManager.instance.remove(note)
                })
            case .failure(let error):
                print("Remove cloud kit error \(error)")
            }
        })
    }
 
    func getRecord(note: Note, completion: @escaping (CloudKitResult) -> Void) {
        guard note.name.characters.count > 0 else {
            completion(.failure("Note name not found."))
            return
        }
        
        if (!note.cloudKitRecord.isEmpty) {
            let record = CKRecord(archivedData: note.cloudKitRecord)
            completion(.success(record!))
            return
        }
        
        fetchRecord(recordName: note.name, completion: { result in
            completion(result)
        })
    }
    
    func fetchRecord(recordName: String, completion: @escaping (CloudKitResult) -> Void) {
        let recordID = CKRecordID(recordName: recordName, zoneID: getZone())
        database.fetch(withRecordID: recordID, completionHandler: { record, error in
            if error != nil {
                completion(.failure("Fetch error \(error!.localizedDescription)"))
                return
            }
            completion(.success(record!))
        })
    }
    
    func createRecord(_ note: Note) -> CKRecord {
        let recordID = CKRecordID(recordName: note.name, zoneID: getZone())
        let record = CKRecord(recordType: "Note", recordID: recordID)
        return fillRecord(note: note, record: record)
    }
    
    func fillRecord(note: Note, record: CKRecord) -> CKRecord{
        record["file"] = CKAsset(fileURL: note.url)
        record["modifiedAt"] = note.modifiedLocalAt as CKRecordValue?
        return record
    }
    
    func reloadView(note: Note? = nil) {
        DispatchQueue.main.async() {
            let viewController = NSApplication.shared().windows.first!.contentViewController as! ViewController
            if let unwrappedNote = note {
                viewController.reloadView(note: unwrappedNote)
            } else {
                viewController.updateTable(filter: "")
            }
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
    
    func verifyCloudKitSubscription() {
        database.fetch(withSubscriptionID: publicDataSubscriptionID) { (subscription, error) -> Void in
            if subscription == nil {
                self.saveNewCloudKitSubscription()
                return
            }
        }
    }
    
    func saveNewCloudKitSubscription() {
        let publicDataSubscriptionPredicate = NSPredicate(format: "TRUEPREDICATE")
        let publicDataSubscriptionOptions: CKQuerySubscriptionOptions = [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        let publicDataSubscription = CKQuerySubscription(recordType: "Note", predicate: publicDataSubscriptionPredicate, subscriptionID: publicDataSubscriptionID, options: publicDataSubscriptionOptions)
        
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        
        publicDataSubscription.notificationInfo = notificationInfo
        
        database.save(publicDataSubscription) { (subscription, error) -> Void in
            if let saveError = error {
                print("Could not save subscription to CloudKit database, error: \(saveError)")
                return
            }
            print("Saved subscription to CloudKit database")
        }
    }
}
