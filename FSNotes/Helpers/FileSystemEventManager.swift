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
    private var observedFolders: [String]
    
    init(storage: Storage, delegate: ViewController) {
        self.storage = storage
        self.delegate = delegate
        self.observedFolders = self.storage.getProjectPaths()
    }
    
    public func start() {
        watcher = FileWatcher(self.observedFolders)
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
            
            if event.fileRemoved || event.dirRemoved {
                guard let note = self.storage.getBy(url: url), let project = note.project, project.isTrash else { return }
                
                self.removeNote(note: note)
            }
            
            if event.fileRenamed || event.dirRenamed {
                self.moveHandler(url: url, pathList: self.observedFolders)
                return
            }
            
            guard self.checkFile(url: self.handleTextBundle(url: url), pathList: self.observedFolders) else {
                return
            }
            
            // order is important, invoke only before change
            if event.fileCreated {
                self.importNote(self.handleTextBundle(url: url))
                return
            }
            
            if event.fileChange,
                let note = self.storage.getBy(url: self.handleTextBundle(url: url))
            {
                if note.isMarkdown() {
                    if let content = try? String(contentsOf: url),
                        content != note.content.string {
                        note.reloadFileContent()
                        note.markdownCache()
                        self.delegate.refillEditArea()
                    }
                } else {
                    self.delegate.refillEditArea()
                }
            }
        }
        
        watcher?.start()
    }
    
    private func moveHandler(url: URL, pathList: [String]) {
        let fileExistInFS = self.checkFile(url: url, pathList: pathList)
        
        guard let note = self.storage.getBy(url: url) else {
            if fileExistInFS {
                self.importNote(url)
            }
            return
        }
        
        if fileExistInFS {
            renameNote(note: note)
            return
        }
        
        removeNote(note: note)
    }
    
    private func checkFile(url: URL, pathList: [String]) -> Bool {
        return (
            FileManager.default.fileExists(atPath: url.path)
            && self.storage.allowedExtensions.contains(url.pathExtension)
            && pathList.contains(url.deletingLastPathComponent().path)
        )
    }
    
    private func importNote(_ url: URL) {
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
    
    private func renameNote(note: Note) {
        if note.url == UserDataService.instance.lastRenamed {
            self.delegate.updateTable() {
                self.delegate.notesTableView.setSelected(note: note)
                UserDataService.instance.lastRenamed = nil
            }
        }
    }
    
    private func removeNote(note: Note) {
        print("FSWatcher remove note: \"\(note.name)\"")
        
        self.storage.removeNotes(notes: [note], fsRemove: false) { _ in
            DispatchQueue.main.async {
                if self.delegate.notesTableView.numberOfRows > 0 {
                    self.delegate.notesTableView.removeByNotes(notes: [note])
                }
            }
        }
    }
    
    private func handleTextBundle(url: URL) -> URL {
        if url.lastPathComponent == "text.markdown" && url.path.contains(".textbundle") {
            let path = url.deletingLastPathComponent().path
            return URL(fileURLWithPath: path)
        }
        
        return url
    }
    
    public func restart() {
        watcher?.stop()
        self.observedFolders = self.storage.getProjectPaths()
        start()
    }
}
