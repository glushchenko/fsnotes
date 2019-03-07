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
    private var cloudDriveResults: [URL]?
    
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

        self.saveCloudDriveResultsCache()

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: cloudDriveQuery)
        
        cloudDriveQuery.enableUpdates()
    }
    
    @objc func handleMetadataQueryUpdates(notification: NSNotification) {
        cloudDriveQuery.disableUpdates()
        
        self.change(notification: notification)
        self.download(notification: notification)
        self.remove(notification: notification)

        self.saveCloudDriveResultsCache()

        cloudDriveQuery.enableUpdates()
        
        self.delegate.updateNotesCounter()
    }

    private func saveCloudDriveResultsCache() {
        self.cloudDriveResults = self.cloudDriveQuery.results.map { ($0 as! NSMetadataItem).value(forAttribute: NSMetadataItemURLKey) as? URL } as? [URL]
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

                note.loadTags()

                if let editorNote = EditTextView.note, editorNote.isEqualURL(url: url), let curDate = currentDate, curDate > Int(note.modifiedLocalAt.timeIntervalSince1970) {
                    _ = note.reload()
                    self.delegate.refreshTextStorage(note: note)
                } else {
                    _ = note.reload()
                }

                note.invalidateCache()
                self.delegate.notesTable.updateRowView(note: note)
                self.resolveConflict(url: url)
                continue
            }

            if let prevNote = getOldNote(item: item), prevNote.url != url {
                DispatchQueue.main.async {
                    if self.delegate.notesTable.notes.contains(where: {$0 === prevNote}) {
                        self.delegate.notesTable.removeByNotes(notes: [prevNote])
                    }

                    prevNote.url = url
                    prevNote.loadTags()
                    prevNote.parseURL()

                    self.delegate.notesTable.insertRow(note: prevNote)
                }

                continue
            }

            if isDownloaded(url: url), storage.allowedExtensions.contains(url.pathExtension) {
                self.add(url: url)
                continue
            }
        }
    }

    private func getOldNote(item: NSMetadataItem) -> Note? {
        let index = self.cloudDriveQuery.index(ofResult: item)

        if let results = self.cloudDriveResults, results.indices.contains(index) {
            let prevURL = results[index] as URL
            if let note = self.storage.getBy(url: prevURL) {
                return note
            }
        }

        return nil
    }
    
    private func download(notification: NSNotification) {
        if let addedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            for item in addedMetadataItems {
                guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }

                if FileManager.default.isUbiquitousItem(at: url) {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                }

                if isDownloaded(url: url), storage.allowedExtensions.contains(url.pathExtension) {
                    self.add(url: url)
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
    
    private func add(url: URL) {
        guard self.storage.getBy(url: url) == nil, let note = self.storage.initNote(url: url) else { return }

        note.loadTags()
        _ = note.reload()

        self.storage.noteList.append(note)
        self.delegate.notesTable.insertRow(note: note)
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

                guard
                    let note = Storage.sharedInstance().initNote(url: conflict.url),
                    let conflictNote = Storage.sharedInstance().initNote(url: to) else { continue }

                note.load(tags: false)

                conflictNote.content = note.content
                conflictNote.write()

                self.storage.add(conflictNote)

                conflict.isResolved = true
            }
        }
    }
    
    private func moveToTrash(note: Note, url: URL) {
        note.url = url
        
        DispatchQueue.main.async {
            var isTrash = false
            let sidebarItem = self.delegate.sidebarTableView.getSidebarItem()

            if let sidebarItem = sidebarItem, sidebarItem.isTrash() {
                isTrash = true
            }
            
            if !isTrash,
                self.delegate.isFit(note: note, sidebarItem: sidebarItem),
                let i = self.delegate.notesTable.notes.index(where: {$0 === note}) {
                
                self.delegate.notesTable.notes.remove(at: i)
                self.delegate.notesTable.deleteRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
            }
            
            if isTrash {
                self.delegate.notesTable.notes.insert(note, at: 0)
                self.delegate.notesTable.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
            }
            
            note.parseURL()
        }
    }
}
