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
    let viewController = NSApplication.shared.windows.first!.contentViewController as! ViewController
    
    init() {
        container = CKContainer.init(identifier: identifier)
        database = container.privateCloudDatabase
        recordZone = CKRecordZone(zoneName: zone)
        makeZone()
    }
    
    func makeZone() {
        database.save(recordZone!, completionHandler: {(recordzone, error) in
            if (error != nil) {
                print("Zone creation error")
            }
        })
    }
    
    func getZone() -> CKRecordZoneID {
        return recordZone!.zoneID
    }
    
    func sync() {
        push()
        pull()
        
        UserDefaultsManagement.lastSync = Date()
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
                    if !note.cloudKitRecord.isEmpty {
                        if let prevRecord = CKRecord(archivedData: note.cloudKitRecord) {
                            if prevRecord.recordChangeTag == record.recordChangeTag {
                                continue
                            }
                        }
                    }
                    
                    note.content = content
                    note.cloudKitRecord = record.data()
                    note.url = Storage.instance.getGeneralURL().appendingPathComponent(fileName)
                    note.extractUrl()
                    
                    if (note.writeContent()) {
                        note.loadModifiedLocalAt()
                        CoreDataManager.instance.save()
                        self.reloadView(note: note)
                        print("Note downloaded: \(note.name)")
                    }
                    
                } catch {}
            }
            
            for recordId in deletedRecords {
                let note = Storage.instance.getBy(name: recordId.recordName)
                if let unwrappedNote = note {
                    DispatchQueue.main.async() {
                        self.viewController.notesTableView.removeNote(unwrappedNote)
                    }
                }
            }
            
            UserDefaults.standard.serverChangeToken = token
        }
    }
    
    func push() {
        guard let note = Storage.instance.getModified() else {
            print("Nothing to push.")
            return
        }
        
        getRecord(note: note, completion: { result in
            self.saveNote(note)
        })
    }
    
    func saveNote(_ note: Note) {
        if !note.isGeneral() {
            Swift.print("Skipped, note not in general storage.")
            return
        }
        
        guard !hasActivePushConnection && note.name.count > 0 else {
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
    
    func saveRecord(note: Note, sRecord: CKRecord, push: Bool = true) {
        database.save(sRecord) { (record, error) in
            self.hasActivePushConnection = false
            
            guard error == nil else {
                print("Save \(note.name) error \(error.debugDescription)")
                
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
                    return
                }
                
                print("Save \(note.name) error \(error.debugDescription)")
                return
            }

            self.updateNoteRecord(note: note, record: record)
            print("Successfully saved: \(note.name)")
            
            if push {
                self.push()
            }
        }
    }
    
    func resolveConflict(note: Note, sRecord: CKRecord) {
        self.fetchRecord(recordName: note.name, completion: { result in
            switch result {
            case .success(let fetchedRecord):
                do {
                    let file = fetchedRecord.object(forKey: "file") as! CKAsset
                    let content = try NSString(contentsOf: file.fileURL, encoding: String.Encoding.utf8.rawValue) as String
                    
                    let conflictedNote = CoreDataManager.instance.make()
                    let date = fetchedRecord.object(forKey: "modifiedAt") as! Date
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [
                        .withYear,
                        .withMonth,
                        .withDay,
                        .withTime
                    ]
                    let dateString: String = dateFormatter.string(from: date)
                    conflictedNote.url = conflictedNote.getUniqueFileName(name: note.title, prefix: " (CONFLICT " + dateString + ")")
                    conflictedNote.extractUrl()
                    conflictedNote.content = content
                    
                    self.updateNoteRecord(note: note, record: fetchedRecord)
                    self.saveRecord(note: note, sRecord: fetchedRecord, push: false)
                    
                    let textStorage = NSTextStorage(attributedString: NSAttributedString(string: content))
                    conflictedNote.save(textStorage)
                    self.reloadView(note: conflictedNote)
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
        
        if note.modifiedLocalAt == record["modifiedAt"] as? Date || note.cloudKitRecord.isEmpty {
            note.isSynced = true
        }
        
        note.cloudKitRecord = record.data()
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
        guard note.name.count > 0 else {
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
            if let unwrappedNote = note {
                self.viewController.reloadView(note: unwrappedNote)
            } else {
                self.viewController.updateTable(filter: "")
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
            print("Changed: \(record.recordID.recordName)")
            changedRecords.append(record)
        }
        
        var deletedRecordIDs: [CKRecordID] = []
        operation.recordWithIDWasDeletedBlock = { (recordID: CKRecordID, identifier: String) in
            print("Deleted: \(recordID.recordName)")
            deletedRecordIDs.append(recordID)
        }
        
        var serverChangesToken: CKServerChangeToken?
        
        operation.recordZoneFetchCompletionBlock = { (zoneID: CKRecordZoneID, token: CKServerChangeToken?, _: Data?, _: Bool, error: Error?) in
            if let error = error {
                print("Error recordZoneFetchCompletionBlock: \(error.localizedDescription)")
                return
            }
            
            print("Pull. Record zone changed: \(token != UserDefaults.standard.serverChangeToken )")
            serverChangesToken = token
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
    
    func flush() {
        database.delete(withRecordZoneID: getZone()) { (recordZoneID, error) -> Void in
            if let error = error {
                print("Flush error: \(error)")
                return
            }
            CoreDataManager.instance.removeCloudKitRecords()
            UserDefaults.standard.serverChangeToken = nil
            self.makeZone()
        }
    }
}
