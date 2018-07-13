//
//  FileSystemEventManager.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/13/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class FileSystemEventManager {
    private var storage: Storage
    private var delegate: ViewController
    private var watcher: FileWatcher?
    
    init(storage: Storage, delegate: ViewController) {
        self.storage = storage
        self.delegate = delegate
    }
    
    public func start() {
        let paths = storage.getProjectPaths()
        
        watcher = FileWatcher(paths)
        watcher?.callback = { event in
            if UserDataService.instance.fsUpdatesDisabled {
                return
            }
            
            guard let path = event.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                return
            }
            
            guard let url = URL(string: "file://" + path) else {
                return
            }
            
            if event.fileRemoved {
                guard let note = self.storage.getBy(url: url), let project = note.project, project.isTrash else { return }
                
                self.storage.removeNotes(notes: [note], fsRemove: false) { _ in
                    DispatchQueue.main.async {
                        if self.delegate.notesTableView.numberOfRows > 0 {
                            self.delegate.notesTableView.removeByNotes(notes: [note])
                        }
                    }
                }
            }
            
            if event.fileRenamed {
                let note = self.storage.getBy(url: url)
                let fileExistInFS = self.checkFile(url: url, pathList: paths)
                
                if note != nil {
                    if fileExistInFS {
                        self.watcherCreateTrigger(url)
                    } else {
                        guard let unwrappedNote = note else {
                            return
                        }
                        
                        print("FSWatcher remove note: \"\(unwrappedNote.name)\"")
                        
                        self.storage.removeNotes(notes: [unwrappedNote], fsRemove: false) { _ in
                            DispatchQueue.main.async {
                                self.delegate.notesTableView.removeByNotes(notes: [unwrappedNote])
                            }
                        }
                    }
                } else if fileExistInFS {
                    self.watcherCreateTrigger(url)
                }
                
                return
            }
            
            guard self.checkFile(url: url, pathList: paths) else {
                return
            }
            
            if event.fileChange {
                let wrappedNote = self.storage.getBy(url: url)
                
                if let note = wrappedNote, note.reload() {
                    note.markdownCache()
                    self.delegate.refillEditArea()
                } else {
                    self.watcherCreateTrigger(url)
                }
                return
            }
            
            if event.fileCreated {
                self.watcherCreateTrigger(url)
            }
        }
        
        watcher?.start()
    }
    
    private func checkFile(url: URL, pathList: [String]) -> Bool {
        return (
            FileManager.default.fileExists(atPath: url.path)
            && self.storage.allowedExtensions.contains(url.pathExtension)
            && pathList.contains(url.deletingLastPathComponent().path)
        )
    }
    
    private func watcherCreateTrigger(_ url: URL) {
        let n = storage.getBy(url: url)
        guard n == nil else {
            if let nUnwrapped = n, nUnwrapped.url == UserDataService.instance.lastRenamed {
                self.delegate.updateTable() {
                    self.delegate.notesTableView.setSelected(note: nUnwrapped)
                    UserDataService.instance.lastRenamed = nil
                }
            }
            return
        }
        
        guard storage.getProjectBy(url: url) != nil else {
            return
        }
        
        let note = Note(url: url)
        note.parseURL()
        note.load(url)
        note.loadModifiedLocalAt()
        note.markdownCache()
        self.delegate.refillEditArea()
        
        print("FSWatcher import note: \"\(note.name)\"")
        self.storage.add(note)
        
        DispatchQueue.main.async {
            if let url = UserDataService.instance.lastRenamed,
                let note = self.storage.getBy(url: url) {
                self.delegate.updateTable() {
                    self.delegate.notesTableView.setSelected(note: note)
                    UserDataService.instance.lastRenamed = nil
                }
            } else {
                self.delegate.reloadView(note: note)
            }
        }
        
        if note.name == "FSNotes - Readme.md" {
            self.delegate.updateTable() {
                self.delegate.notesTableView.selectRow(0)
                note.addPin()
            }
        }
        
        self.delegate.reloadSideBar()
    }
    
    public func restart() {
        watcher?.stop()
        start()
    }
}
