//
//  CloudDriveManager.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 6/13/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class CloudDriveManager {

    private var cloudDriveResults = [URL]()
    
    private weak var delegate: ViewController
    private var storage: Storage

    private var currentDownloadingList = [URL]()
    private var resultsDict: [Int: URL] = [:]

    private var contentDateDict: [Int: Date] = [:]
    private var fileNameDict: [Int: String] = [:]
    private var whiteList = [Int]()
    
    private let workerQueue: OperationQueue = {
        let workerQueue = OperationQueue()
        workerQueue.name = "co.fluder.fsnotes.manager.browserdatasource.workerQueue"
        workerQueue.maxConcurrentOperationCount = 1
        workerQueue.qualityOfService = .background
        return workerQueue
    }()

    public let metadataQuery = NSMetadataQuery()

    init(delegate: ViewController, storage: Storage) {
        metadataQuery.operationQueue = workerQueue
        metadataQuery.searchScopes = [
            NSMetadataQueryUbiquitousDocumentsScope
        ]
        metadataQuery.notificationBatchingInterval = 1
        metadataQuery.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        metadataQuery.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]


        self.delegate = delegate
        self.storage = storage
    }

    @objc func queryDidFinishGathering(notification: NSNotification) {

        let query = notification.object as? NSMetadataQuery

        if let results = query?.results as? [NSMetadataItem] {
            self.saveCloudDriveResultsCache(results: results)
        }

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: self.metadataQuery)

        NotificationCenter.default.addObserver(self, selector: #selector(self.handleMetadataQueryUpdates), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: self.metadataQuery)

        self.metadataQuery.enableUpdates()
    }
    
    @objc func handleMetadataQueryUpdates(notification: NSNotification) {
        guard let metadataQuery = notification.object as? NSMetadataQuery else { return }

        metadataQuery.disableUpdates()

        self.change(notification: notification)
        self.download(notification: notification)
        self.remove(notification: notification)

        if let results = metadataQuery.results as? [NSMetadataItem] {
            self.saveCloudDriveResultsCache(results: results)
        }

        self.delegate.updateNotesCounter()

        metadataQuery.enableUpdates()
    }

    private var lastChangeDate = Date.init(timeIntervalSince1970: .zero)

    private func saveCloudDriveResultsCache(results: [NSMetadataItem]) {
        print("Gathering results saving")

        for result in results {
            let key = metadataQuery.index(ofResult: result)
            if let url = result.value(forAttribute: NSMetadataItemURLKey) as? URL {
                if resultsDict[key] == nil {
                    resultsDict[key] = url.resolvingSymlinksInPath()
                }
            }

            if let date = result.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date {
                contentDateDict[key] = date
            }

            if let name = result.value(forAttribute: NSMetadataItemFSNameKey) as? String {
                fileNameDict[key] = name
            }
        }

        var quantity = 0

        for result in results {
            if let status = result.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String, status != NSMetadataUbiquitousItemDownloadingStatusCurrent,
                let url = (result.value(forAttribute: NSMetadataItemURLKey) as? URL)?.resolvingSymlinksInPath(), !currentDownloadingList.contains(url) {

                do {

                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    currentDownloadingList.append(url)
                    quantity += 1
                    print("DL starts at url: \(url)")
                } catch {

                    print("DL starts failed at url: \(url) – \(error)")
                }
            }
        }

        print("Finish iCloud Drive results saving. DL started for: \(quantity) items")
    }

    private func change(notification: NSNotification) {
        guard let changedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] else { return }

        print("Changed: \(changedMetadataItems.count)")

        for item in changedMetadataItems {
            let index = metadataQuery.index(ofResult: item)
            let date = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
            let fileName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String
            guard let url = (item.value(forAttribute: NSMetadataItemURLKey) as? URL)?.resolvingSymlinksInPath() else { continue }

            if contentDateDict[index] == date
                && resultsDict[index] == url
                && fileNameDict[index] == fileName
                && changedMetadataItems.count != 1
                && !whiteList.contains(index) {
                continue
            }

            guard self.storage.allowedExtensions.contains(url.pathExtension) else {
                continue
            }

            if let note = storage.getBy(url: url) {
                if note.isTextBundle() && !note.isFullLoadedTextBundle() {
                    continue
                }

                guard let date = note.getFileModifiedDate() else { continue }

                note.loadTags()
                
                if changedMetadataItems.count == 1 {
                    let coreNote = CoreNote(fileURL: note.url)
                    coreNote.open()
                }

                note.forceReload()

                if let editorNote = EditTextView.note, editorNote.isEqualURL(url: url), date > note.modifiedLocalAt {
                    note.modifiedLocalAt = date
                    self.delegate.refreshTextStorage(note: note)
                }

                note.invalidateCache()
                self.delegate.notesTable.reloadRow(note: note)

                self.resolveConflict(url: url)
                continue
            }

            if let prevNote = getOldNote(item: item, url: url) {
                print("Found old, renamed: \(url)")
                DispatchQueue.main.async {
                    self.delegate.notesTable.removeByNotes(notes: [prevNote])

                    prevNote.url = url
                    prevNote.loadTags()
                    prevNote.parseURL()

                    self.resultsDict[index] = url
                    self.delegate.notesTable.insertRow(note: prevNote)
                }

                continue
            }

            if isDownloaded(url: url), storage.allowedExtensions.contains(url.pathExtension) {
                self.add(url: url)
            }
        }
    }

    private func getOldNote(item: NSMetadataItem, url: URL) -> Note? {
        let index = self.metadataQuery.index(ofResult: item)
        guard let prevURL = resultsDict[index] else { return nil }

        if resultsDict[index] != url {
            if let note = storage.getBy(url: prevURL) {
                return note
            }
        }

        return nil
    }
    
    private func download(notification: NSNotification) {
        if let addedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            for item in addedMetadataItems {
                guard let url = (item.value(forAttribute: NSMetadataItemURLKey) as? URL)?.resolvingSymlinksInPath() else { continue }

                if isDownloaded(url: url), storage.allowedExtensions.contains(url.pathExtension) {
                    self.add(url: url)
                    continue
                }

                if FileManager.default.isUbiquitousItem(at: url) {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)

                    let index = metadataQuery.index(ofResult: item)
                    if !whiteList.contains(index) {
                        whiteList.append(index)
                    }
                }
            }
        }
    }
    
    private func remove(notification: NSNotification) {
        if let removedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] {
            
            for item in removedMetadataItems {
                guard let url = (item.value(forAttribute: NSMetadataItemURLKey) as? URL)?.resolvingSymlinksInPath(), let note = storage.getBy(url: url) else { continue }

                self.storage.removeNotes(notes: [note], completely: true) {_ in
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

    public func add(url: URL) {
        guard self.storage.getBy(url: url) == nil, let note = self.storage.initNote(url: url) else { return }

        if note.isTextBundle() && !note.isFullLoadedTextBundle() {
            return
        }

        note.loadTags()
        _ = note.reload()

        print("New note imported: \(url)")
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
                let i = self.delegate.notesTable.notes.firstIndex(where: {$0 === note}) {
                
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
