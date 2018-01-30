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
    case failure(CKError)
}

protocol CloudKitManagerDelegate: NSObjectProtocol {
    func reloadView(note: Note?)
    func refillEditArea(cursor: Int?, previewOnly: Bool)
}

class CloudKitManager {

    weak var delegate : CloudKitManagerDelegate?
    let identifier = "iCloud.co.fluder.fsnotes"
    let notesZone = "NotesZone"
    
    var container: CKContainer
    var modifiedRecords: [CKRecord] = []
    var database: CKDatabase
    var recordZone: CKRecordZone?
    var storage = Storage.instance
    var queryCompletionBlock: (CKQueryCursor?, Error?) -> Void = { (_,_) in }
    let modifyQueueList = [String: Note]()
    var hasActivePushConnection: Bool = false
    let publicDataSubscriptionID = "cloudKitCreateUpdateDeleteSubscription"
    var controller: ViewController?
    
    class func sharedInstance() -> CloudKitManager {
        return CloudKitManagerSingleton
    }
    
    init() {
        container = CKContainer.init(identifier: identifier)
        database = container.privateCloudDatabase
    }
    
    func makeZone(completion: @escaping (CKRecordZone?) -> Void) {
        database.save(CKRecordZone.init(zoneName: notesZone), completionHandler: {(recordZone, error) in
            if (error != nil) {
                print("Zone creation error")
                return
            }
            
            print("Zone successfully created")
            completion(recordZone)
        })
    }
    
    func fetchZone(completion: @escaping (CKRecordZone?) -> Void) {
        database.fetchAllRecordZones { zones, error in
            guard let zones = zones, error == nil else {
                self.makeZone() { (record) in
                    completion(record)
                }
                return
            }
            
            for zone in zones {
                if zone.zoneID.zoneName == self.notesZone {
                    completion(zone)
                    return
                }
            }
            
            self.makeZone() { (record) in
                completion(record)
            }
        }
    }
    
    func getZone(completion: @escaping (CKRecordZone?) -> Void) {
        guard let zone = recordZone else {
            fetchZone() { (record) in
                self.recordZone = record
                completion(record)
            }
            return
        }
        
        completion(zone)
    }
    
    func sync() {
        NotificationsController.onStartSync()
        
        getZone() { (recordZone) in
            guard recordZone != nil else {
                return
            }
            
            self.push() {
                self.pull()
            }
            
            UserDefaultsManagement.lastSync = Date()
        }
    }
    
    func pull() {
        fetchChanges() {modifiedRecords, deletedRecords, token in
            Storage.fsImportIsAvailable = false

            for record in modifiedRecords {
                let asset = record.object(forKey: "file") as! CKAsset
                let recordName = record.recordID.recordName
                let fileName = recordName as String
                
                let note = Storage.instance.getOrCreate(name: fileName)
                if !note.cloudKitRecord.isEmpty {
                    if let prevRecord = CKRecord(archivedData: note.cloudKitRecord) {
                        if prevRecord.recordChangeTag == record.recordChangeTag {
                            continue
                        }
                    }
                }
                
                note.cloudKitRecord = record.data()
                note.isSynced = true
                note.initWith(url: asset.fileURL, fileName: fileName)
                self.delegate?.refillEditArea(cursor: nil, previewOnly: false)
                
                note.save()
                
                print("Note downloaded: \(note.name)")
            }
            
            for recordId in deletedRecords {
                var notes: [Note] = []
                
                if let note = Storage.instance.getBy(name: recordId.recordName) {
                    notes.append(note)
                }
                
                Storage.instance.removeNotes(notes: notes)
            }
            
            CoreDataManager.instance.save()
            Storage.fsImportIsAvailable = true
            UserDefaults.standard.serverChangeToken = token

            DispatchQueue.main.async {
                self.delegate?.reloadView(note: nil)
                NotificationsController.syncProgress()
                NotificationsController.onFinishSync()
            }
        }
    }
    
    func push(completionPush: @escaping () -> Void) {
        guard let note = Storage.instance.getModified() else {
            print("Nothing to push.")
            NotificationsController.onFinishSync()
            NotificationsController.syncProgress()
            completionPush()
            return
        }
        
        guard recordZone != nil else {
            print("Push skipped, zone not found.")
            return
        }
        
        getRecord(note: note, completion: { result in
            self.saveNote(note) {
                completionPush()
            }
        })
    }
    
    func saveNote(_ note: Note, completionSave: @escaping () -> Void) {
        getZone() { (recordZone) in
            guard recordZone != nil else {
                completionSave()
                return
            }
        
            if !note.isGeneral() {
                print("Skipped, note not in general storage.")
                completionSave()
                return
            }
            
            guard !self.hasActivePushConnection && note.name.count > 0 else {
                note.syncSkipDate = Date()
                completionSave()
                return
            }
            
            note.syncDate = Date()
            
            self.hasActivePushConnection = true
            var record: CKRecord? = nil
            
            if note.cloudKitRecord.isEmpty {
                record = self.createRecord(note)
            } else {
                record = CKRecord(archivedData: note.cloudKitRecord)!
                if let unwrappedRecord = record {
                    record = self.fillRecord(note: note, record: unwrappedRecord)
                }
            }
            
            guard let unwrappedRecord = record else {
                self.hasActivePushConnection = false
                completionSave()
                return
            }
            
            if note.storage == nil {
                note.storage = CoreDataManager.instance.fetchGeneralStorage()
            }
            
            self.saveRecord(note: note, sRecord: unwrappedRecord) {
                completionSave()
            }
        }
    }
    
    func saveRecord(note: Note, sRecord: CKRecord, push: Bool = true, completionSave: @escaping () -> Void) {
        database.save(sRecord) { (record, error) in
            self.hasActivePushConnection = false
            
            guard error == nil else {
                print("Save \(note.name) error \(error.debugDescription)")
                
                if error?._code == CKError.serverRecordChanged.rawValue {
                    print("Server record changed. Need resolve conflict.")
                    self.resolveConflict(note: note, sRecord: sRecord) {
                        completionSave()
                    }
                    return
                }
                
                if error?._code == CKError.assetFileModified.rawValue {
                    self.saveNote(note) {
                        completionSave()
                    }
                    return
                }
                
                if error?._code == CKError.unknownItem.rawValue {
                    completionSave()
                    return
                }
                
                completionSave()
                return
            }

            self.updateNoteRecord(note: note, record: record)
            print("Successfully saved: \(note.name)")
            
            if push {
                self.push() {
                    completionSave()
                }
            }
        }
    }
    
    func resolveConflict(note: Note, sRecord: CKRecord, completionResolve: @escaping () -> Void) {
        let storage = CoreDataManager.instance.fetchGeneralStorage()
        
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
                    conflictedNote.parseURL()
                    conflictedNote.content = NSMutableAttributedString(string: content)
                    conflictedNote.storage = storage
                    conflictedNote.markdownCache()
                    self.delegate?.refillEditArea(cursor: nil, previewOnly: false)
                    
                    self.updateNoteRecord(note: note, record: fetchedRecord)
                    self.saveRecord(note: note, sRecord: fetchedRecord, push: false) {
                        completionResolve()
                    }
                    
                    conflictedNote.save()
                    self.delegate?.reloadView(note: conflictedNote)
                } catch {}
                
            case .failure(let error):
                print("Fetch failure \(error)")
                completionResolve()
            }
        })
    }
    
    func updateNoteRecord(note: Note, record: CKRecord?) {
        guard let record = record else {
            print("Record not found")
            return
        }
        
        if let syncDate = note.syncDate, let syncSkipDate = note.syncSkipDate, syncSkipDate > syncDate {
            note.isSynced = false
        } else {
            note.isSynced = true
        }
        
        note.cloudKitRecord = record.data()
        CoreDataManager.instance.save()
    }
    
    func removeRecord(note: Note, completionRecord: @escaping () -> Void) {
        getRecord(note: note, completion: { result in
            switch result {
            case .success(let record):
                self.database.delete(withRecordID: record.recordID, completionHandler: { record, error in
                    let name = note.name
                    CoreDataManager.instance.remove(note)
                    completionRecord()
                    print("Removed successfully: \(name)")
                })
            case .failure(let error):
                CoreDataManager.instance.remove(note)
                completionRecord()
                print("Remove cloud kit error \(error)")
            }
        })
    }
 
    func getRecord(note: Note, completion: @escaping (CloudKitResult) -> Void) {
        guard note.name.count > 0 else {
            completion(.failure(CKError(_nsError: NSError())))
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
        let recordID = CKRecordID(recordName: recordName, zoneID: recordZone!.zoneID)
        database.fetch(withRecordID: recordID, completionHandler: { record, error in
            if error != nil {
                completion(.failure(error as! CKError))
                return
            }
            completion(.success(record!))
        })
    }
    
    func createRecord(_ note: Note) -> CKRecord {
        let recordID = CKRecordID(recordName: note.name, zoneID: recordZone!.zoneID)
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
                self.delegate?.reloadView(note: unwrappedNote)
            }
        }
    }
    
    func removeRecords(records: [CKRecordID], completion: @escaping () -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: records)
        operation.qualityOfService = .userInitiated
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if let records = deletedRecordIDs {
                print("CloudKit remove: \(records.map{ $0.recordName }.joined(separator: ", "))")
                completion()
                return
            }
            completion()
        }
        database.add(operation)
    }
    
    func fetchChanges(completion: @escaping ([CKRecord], [CKRecordID], CKServerChangeToken?) -> Void) {
        let zonedId = recordZone!.zoneID
        
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
            
            let zoneChanged = (token != UserDefaults.standard.serverChangeToken)
            if zoneChanged {
                serverChangesToken = token
            }
        }
        
        operation.fetchRecordZoneChangesCompletionBlock = { (error: Error?) in
            if let error = error {
                let value = error as! CKError
                
                // Reset server change key if zone removed and re-download records
                if value.code.rawValue == 2 {
                    UserDefaults.standard.serverChangeToken = nil
                    self.pull()
                }
                
                print("Zone changes error: \(error)")
                NotificationsController.onFinishSync()
                return
            }
            
            if let token = serverChangesToken, error == nil {
                completion(changedRecords, deletedRecordIDs, token)
                return
            }
            
            print("Nothing to pull.")
            
            NotificationsController.onFinishSync()
        }
        
        operation.qualityOfService = .userInitiated
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
        getZone() { (recordZone) in
            guard let zone = recordZone else {
                return
            }
            
            self.database.delete(withRecordZoneID: zone.zoneID) { (recordZoneID, error) -> Void in
                if let error = error {
                    print("Flush error: \(error)")
                    return
                }
                
                self.recordZone = nil
                
                print("Remote CloudKit data removed")
                CoreDataManager.instance.removeCloudKitRecords()
                UserDefaults.standard.serverChangeToken = nil
                Storage.instance.loadDocuments()
                
                NotificationsController.syncProgress()
                self.sync()
            }
        }
    }
}

let CloudKitManagerSingleton = CloudKitManager()
