//
//  CloudDriveManager.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 6/13/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class CloudDriveManager {

    public var cloudDriveQuery: NSMetadataQuery
    
    private var delegate: ViewController
    private var storage: Storage
    
    private let workerQueue: OperationQueue = {
        let workerQueue = OperationQueue()
        workerQueue.name = "co.fluder.fsnotes.manager.browserdatasource.workerQueue"
        workerQueue.maxConcurrentOperationCount = 1
        return workerQueue
    }()
    
    init(delegate: ViewController, storage: Storage) {
        let metadataQuery = NSMetadataQuery()
        metadataQuery.operationQueue = workerQueue
        metadataQuery.searchScopes = [
            NSMetadataQueryUbiquitousDocumentsScope
        ]
        
        metadataQuery.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        metadataQuery.enableUpdates()
        metadataQuery.start()
        
        self.delegate = delegate
        self.cloudDriveQuery = metadataQuery
        self.storage = storage
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMetadataQueryUpdates), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)
        
        NotificationCenter.default.addObserver(self, selector: #selector(queryDidFinishGathering), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)
    }
    
    @objc func queryDidFinishGathering(notification: NSNotification) {
        cloudDriveQuery.disableUpdates()
        cloudDriveQuery.stop()

        if let items = cloudDriveQuery.results as? [NSMetadataItem] {
            for item in items {
                if  let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                    let note = self.storage.getBy(url: url) {
                    note.metaId = self.cloudDriveQuery.index(ofResult: item)
                }
            }
        }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: cloudDriveQuery)
        
        cloudDriveQuery.start()
        cloudDriveQuery.enableUpdates()
    }
    
    @objc func handleMetadataQueryUpdates(notification: NSNotification) {
        cloudDriveQuery.disableUpdates()
        
        self.change(notification: notification)
        self.download(notification: notification)
        self.remove(notification: notification)
        
        cloudDriveQuery.enableUpdates()
    }
    
    private func change(notification: NSNotification) {
        guard let changedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] else { return }
        
        for item in changedMetadataItems {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL, self.storage.allowedExtensions.contains(url.pathExtension) else {
                continue
            }

            if let note = storage.getBy(url: url) {
                var currentDate: Int? = nil
                if let date = note.getFileModifiedDate() {
                    currentDate = Int(date.timeIntervalSince1970)
                }

                if url == EditTextView.note?.url, let curDate = currentDate, curDate > Int(note.modifiedLocalAt.timeIntervalSince1970) {
                    _ = note.reload()
                    self.delegate.refreshTextStorage(note: note)
                } else {
                    _ = note.reload()
                }

                DispatchQueue.main.async {
                    if let i = self.delegate.notesTable.notes.firstIndex(of: note) {
                        self.delegate.notesTable.beginUpdates()
                        self.delegate.notesTable.reloadRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
                        self.delegate.notesTable.endUpdates()
                    }
                }

                self.resolveConflict(url: url)
                continue
            }

            let index = cloudDriveQuery.index(ofResult: item)

            if let prevNote = self.storage.getBy(metaId: index) {
                if url.deletingLastPathComponent().lastPathComponent == ".Trash" {
                    self.moveToTrash(note: prevNote, url: url)
                    continue
                }

                if prevNote.url != url {

                    DispatchQueue.main.async {
                        if self.delegate.notesTable.notes.contains(prevNote) {
                            self.delegate.notesTable.removeByNotes(notes: [prevNote])
                        }

                        prevNote.url = url
                        prevNote.loadTags()
                        prevNote.parseURL()

                        self.insertRow(note: prevNote)
                    }

                    continue
                }
            }

            if isDownloaded(url: url), storage.allowedExtensions.contains(url.pathExtension) {
                self.add(url: url, metaId: index)
                continue
            }
        }
    }
    
    private func download(notification: NSNotification) {
        if let addedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            for item in addedMetadataItems {
                guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }

                if FileManager.default.isUbiquitousItem(at: url) {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                }

                if isDownloaded(url: url), storage.allowedExtensions.contains(url.pathExtension) {
                    let index = cloudDriveQuery.index(ofResult: item)
                    self.add(url: url, metaId: index)
                }
            }
        }
    }
    
    private func remove(notification: NSNotification) {
        if let removedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] {
            
            for item in removedMetadataItems {
                guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL, let note = storage.getBy(url: url) else { continue }

                self.storage.removeNotes(notes: [note]) {_ in
                    DispatchQueue.main.async {
                        self.delegate.notesTable.removeByNotes(notes: [note])
                    }
                }
            }
        }
    }
    
    private func isDownloaded(url: URL) -> Bool {
        var isDownloaded: AnyObject? = nil
        
        do {
            try (url as NSURL).getResourceValue(&isDownloaded, forKey: URLResourceKey.ubiquitousItemDownloadingStatusKey)
        } catch _ {}
        
        if isDownloaded as? URLUbiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current {
            return true
        }
        
        return false
    }
    
    private func add(url: URL, metaId: Int) {
        guard self.storage.getBy(url: url) == nil else { return }

        let note = Note(url: url)
        note.metaId = metaId
        note.loadTags()
        _ = note.reload()

        self.storage.noteList.append(note)
        self.insertRow(note: note)
    }

    private func insertRow(note: Note) {
        let i = self.delegate.getInsertPosition()

        DispatchQueue.main.async {
            if self.delegate.isFitInSidebar(note: note), !self.delegate.notesTable.notes.contains(note) {

                self.delegate.notesTable.notes.insert(note, at: i)
                self.delegate.notesTable.beginUpdates()
                self.delegate.notesTable.insertRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
                self.delegate.notesTable.reloadRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
                self.delegate.notesTable.endUpdates()
            }
        }
    }
    
    private func resolveConflict(url: URL) {
        if let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url as URL) {
            for conflict in conflicts {
                guard let localizedName = conflict.localizedName else {
                    continue
                }

                let localizedUrl = URL(fileURLWithPath: localizedName)
                let ext = url.pathExtension
                let name = localizedUrl.deletingPathExtension().lastPathComponent

                let date = Date.init()
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [
                    .withYear,
                    .withMonth,
                    .withDay,
                    .withTime
                ]
                let dateString: String = dateFormatter.string(from: date)
                let conflictName = "\(name) (CONFLICT \(dateString)).\(ext)"
                
                let to = url.deletingLastPathComponent().appendingPathComponent(conflictName)
                let note = Note(url: conflict.url)
                note.loadContent()

                let conflictNote = Note(url: to)
                conflictNote.content = note.content
                conflictNote.save(to: to, for: .forCreating, completionHandler: nil)
                
                conflict.isResolved = true
            }
        }
    }
    
    private func moveToTrash(note: Note, url: URL) {
        note.url = url
        
        DispatchQueue.main.async {
            var isTrash = false
            if let sidebarItem = self.delegate.getSidebarItem(), sidebarItem.isTrash() {
                isTrash = true
            }
            
            if !isTrash,
                self.delegate.isFitInSidebar(note: note),
                let i = self.delegate.notesTable.notes.index(of: note) {
                
                self.delegate.notesTable.notes.remove(at: i)
                self.delegate.notesTable.beginUpdates()
                self.delegate.notesTable.deleteRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
                self.delegate.notesTable.endUpdates()
            }
            
            if isTrash {
                self.delegate.notesTable.notes.insert(note, at: 0)
                self.delegate.notesTable.beginUpdates()
                self.delegate.notesTable.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                self.delegate.notesTable.endUpdates()
            }
            
            note.parseURL()
        }
    }
}
