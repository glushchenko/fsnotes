//
//  CloudDriveManager.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 6/13/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit

class CloudDriveManager {

    private var cloudDriveResults = [URL]()
    
    private var delegate: ViewController
    private var storage: Storage

    public let metadataQuery = NSMetadataQuery()
    private var resultsDict = NSMutableDictionary()
    private let workerQueue: OperationQueue = {
        let workerQueue = OperationQueue()
        workerQueue.name = "co.fluder.fsnotes.manager.browserdatasource.workerQueue"
        workerQueue.maxConcurrentOperationCount = 1
        workerQueue.qualityOfService = .background
        return workerQueue
    }()

    private var shouldLoadTags: Bool = false

    private var notesInsertionQueue = [Note]()
    private var notesDeletionQueue = [Note]()
    private var notesModificationQueue = [Note]()

    private var projectsInsertionQueue = [Project]()
    private var projectsDeletionQueue = [Project]()

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
            saveCloudDriveResultsCache(results: results)
            startInitialLoading(results: results)
        }

        metadataQuery.enableUpdates()
    }
    
    @objc func handleMetadataQueryUpdates(notification: NSNotification) {
        guard let metadataQuery = notification.object as? NSMetadataQuery else { return }
        metadataQuery.disableUpdates()

        let changed = change(notification: notification)
        let added = self.added(notification: notification)
        let removed = remove(notification: notification)

        doVisualChanges()

        if added > 0 || removed > 0 || changed > 0,
            let results = metadataQuery.results as? [NSMetadataItem] {
            saveCloudDriveResultsCache(results: results)
        }

        metadataQuery.enableUpdates()
    }

    private func saveCloudDriveResultsCache(results: [NSMetadataItem]) {
        let point = Date()

        for result in results {
            if let url = result.value(forAttribute: NSMetadataItemURLKey) as? URL {
                resultsDict[metadataQuery.index(ofResult: result)] = url.standardized
            }
        }

        print("N. iCloud Drive resources: \"\(results.count)\", caching finished in \(point.timeIntervalSinceNow * -1) seconds.")
    }

    private func startInitialLoading(results: [NSMetadataItem]) {
        for metadataItem in results {
            let url = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL
            let status = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String

            if status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded,
                let url = url,
                FileManager.default.isUbiquitousItem(at: url) {

                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                } catch {
                    print("Download error: \(error)")
                }
            }
        }
    }

    private func change(notification: NSNotification) -> Int {
        guard let changedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] else { return 0 }

        var completed = 0
        for item in changedMetadataItems {
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String

            let index = metadataQuery.index(ofResult: item)
            let itemUrl = item.value(forAttribute: NSMetadataItemURLKey) as? URL
            let contentChangeDate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date

            if status == NSMetadataUbiquitousItemDownloadingStatusCurrent {
                completed += 1
            }

            guard let url = itemUrl?.standardized, status == NSMetadataUbiquitousItemDownloadingStatusCurrent else { continue }

            // check projects
            let isDirectory = (try? itemUrl?.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            let isPackage = (try? itemUrl?.resourceValues(forKeys: [.isDirectoryKey]))?.isPackage ?? false

            // Is folder
            if isDirectory && !isPackage && url.pathExtension != "textbundle" {

                // Renamed – remove old
                if let project = getProjectFromCloudDriveResults(item: item) {
                    projectsDeletionQueue.append(project)
                }

                // Add new
                if storage.getProjectBy(url: url) == nil {
                    if let project = storage.addProject(url: url) {
                        projectsInsertionQueue.append(project)
                    }
                }

                continue
            }

            // Is file
            guard storage.isValidNote(url: url) else { continue }

            // Note already exist and update completed
            if let note = storage.getBy(url: url) {
                if note.isTextBundle() && !note.isFullLoadedTextBundle() {
                    continue
                }

                if let currentNote = EditTextView.note,
                    let date = contentChangeDate,
                    currentNote.isEqualURL(url: url),
                    date > note.modifiedLocalAt
                {
                    note.modifiedLocalAt = date

                    note.forceLoad()
                    delegate.refreshTextStorage(note: note)
                }

                print("File changed: \(url)")
                notesModificationQueue.append(note)
                resolveConflict(url: url)

                continue
            }

            // Note previously exist on different path
            if let note = getNoteFromCloudDriveResults(item: item) {

                // moved to unavailable dir (i.e. trash) is equal removed

                guard storage.getProjectByNote(url: url) != nil else {
                    storage.removeNotes(notes: [note], fsRemove: false) {_ in
                        self.notesDeletionQueue.append(note)
                    }

                    print("File moved outside: \(url)")
                    continue
                }

                // moved to available dir
                print("File moved to new url: \(url)")

                notesDeletionQueue.append(note)
                note.url = url
                note.parseURL()

                resultsDict[index] = url
                notesInsertionQueue.append(note)

                continue
            }

            // Non exist yet, will add
            importNote(url: url)
        }

        return completed
    }

    private func getNoteFromCloudDriveResults(item: NSMetadataItem) -> Note? {
        let itemUrl = item.value(forAttribute: NSMetadataItemURLKey) as? URL
        guard let url = itemUrl?.standardized else { return nil }

        let index = self.metadataQuery.index(ofResult: item)
        guard let prev = resultsDict[index] as? URL else { return nil }

        if prev != url {
            if let note = storage.getBy(url: prev) {
                return note
            }
        }

        return nil
    }

    private func getProjectFromCloudDriveResults(item: NSMetadataItem) -> Project? {
        let itemUrl = item.value(forAttribute: NSMetadataItemURLKey) as? URL
        guard let url = itemUrl?.standardized else { return nil }

        let index = self.metadataQuery.index(ofResult: item)
        guard let prev = resultsDict[index] as? URL else { return nil }

        if prev != url {
            if let project = storage.getProjectBy(url: prev) {
                return project
            }
        }

        return nil
    }
    
    private func added(notification: NSNotification) -> Int {
        guard let addedMetadataItems =
            notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]
        else { return 0 }

        for item in addedMetadataItems {
            guard let url = (item.value(forAttribute: NSMetadataItemURLKey) as? URL)?.standardized else { continue }

            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String

            if status != NSMetadataUbiquitousItemDownloadingStatusCurrent
                && FileManager.default.isUbiquitousItem(at: url) {

                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                } catch {
                    print("Download error: \(error)")
                }

                continue
            }

            // when file moved from outspace to FSNotes space
            // i.e. revert from macOS trash to iCloud Drive

            if storage.isValidNote(url: url) {
                self.importNote(url: url)
            }
        }

        return addedMetadataItems.count
    }
    
    private func remove(notification: NSNotification) -> Int {
        guard let removedMetadataItems =
            notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as?
                [NSMetadataItem]
        else { return 0 }

        for item in removedMetadataItems {
            guard let url = (item.value(forAttribute: NSMetadataItemURLKey) as? URL)?.standardized
            else { continue }

            if let note = storage.getBy(url: url) {
                storage.removeNotes(notes: [note], fsRemove: false) {_ in
                    self.notesDeletionQueue.append(note)
                }
            }

            if let project = storage.getProjectBy(url: url) {
                storage.remove(project: project)
                self.projectsDeletionQueue.append(project)
            }
        }

        return removedMetadataItems.count
    }

    public func importNote(url: URL) {
        guard let note = storage.importNote(url: url) else { return }

        print("File imported: \(note.url)")

        if !storage.contains(note: note) {
            storage.noteList.append(note)
            notesInsertionQueue.append(note)
        }
    }

    public func resolveConflict(url: URL) {
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
                let project = Storage.sharedInstance().getMainProject()
                let note = Note(url: conflict.url, with: project)

                guard let conflictNote = Storage.sharedInstance().initNote(url: to) else { continue }

                note.load()

                if note.content.length > 0 {
                    conflictNote.content = note.content
                    conflictNote.write()
                }

                conflict.isResolved = true
            }
        }
    }

    private func doVisualChanges() {
        let insert = notesInsertionQueue
        let delete = notesDeletionQueue
        let change = notesModificationQueue

        notesInsertionQueue.removeAll()
        notesDeletionQueue.removeAll()
        notesModificationQueue.removeAll()

        let projectsDeletion = projectsDeletionQueue
        let projectsInsertion = projectsInsertionQueue

        projectsDeletionQueue.removeAll()
        projectsInsertionQueue.removeAll()

        for note in insert {
            note.forceLoad()
        }

        for note in change {
            note.forceLoad()
        }

        DispatchQueue.main.async {
            self.delegate.notesTable.removeRows(notes: delete)
            self.delegate.notesTable.insertRows(notes: insert)
            self.delegate.notesTable.reloadRows(notes: change)

            self.delegate.sidebarTableView.removeRows(projects: projectsDeletion)
            self.delegate.sidebarTableView.insertRows(projects: projectsInsertion)

            self.delegate.updateNotesCounter()
        }
    }
}
