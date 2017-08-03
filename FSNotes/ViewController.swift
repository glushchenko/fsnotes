//
//  ViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/20/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class ViewController: NSViewController,
    NSTextViewDelegate,
    NSTextFieldDelegate {
    
    var lastSelectedNote: Note?
    
    @IBOutlet weak var searchWrapper: NSTextField!
    @IBOutlet weak var noteList: NSTableView!
    @IBOutlet var editArea: NSTextView!
    @IBOutlet weak var editAreaScroll: NSScrollView!
    @IBOutlet weak var search: NSTextField!
    @IBOutlet weak var notesTableView: NotesTableView!
    
    override func viewDidAppear() {
        self.view.window!.title = "FSNotes"
        
        // autosave size and position
        self.view.window?.setFrameAutosaveName("MainWindow")
        
        // editarea paddings
        editArea.textContainerInset.height = 5
        editArea.textContainerInset.width = 5
        
        super.viewDidAppear()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        editArea.delegate = self
        search.delegate = self
        
        self.populateTable(search: "")
        self.notesTableView.reloadData()
        
        if (self.notesTableView.notesList.indices.contains(0)) {
            self.lastSelectedNote = self.notesTableView.notesList[0]
            editArea.string = notesTableView.notesList[0].content!
        }
        
        let font = NSFont(name: "Source Code Pro", size: 13)
        editArea.font = font
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    // On change text in main editor
    func textDidChange(_ notification: Notification) {
        let content = editArea.string
    
        lastSelectedNote?.content = content
        writeContent(note: lastSelectedNote!, content: content!)
        populateTable(search:"")
        
        notesTableView.reloadData()
        notesTableView.scrollRowToVisible(0)
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        
        notesTableView.notesList.removeAll();
        self.populateTable(search: search.stringValue)
        
        if (notesTableView.notesList.count > 0) {
            editArea.string = notesTableView.notesList[0].content!
            self.selectNullTableRow()
        }

        notesTableView.reloadData()
    }
    
    @IBAction func makeNote(_ sender: NSTextField) {
        let note = Note()
        note.name = search.stringValue
        
        let fileUrl = self.makeUniqueFileName(name: search.stringValue)
        let someText = ""
        
        do {
            try someText.write(to: fileUrl, atomically: false, encoding: String.Encoding.utf8)
        }
        catch { }
        
        self.populateTable(search: "")
        noteList.reloadData()
        
        self.selectNullTableRow()
        
        // cursor position hack
        DispatchQueue.main.async() {
            self.editArea.window?.makeFirstResponder(self.editArea)
        }
    }

    func getPreviewText(url: URL) -> String {
        var fullNote: String = ""
        
        do {
            fullNote = try String(contentsOf: url, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        return fullNote
    }
    
    func getModificationDate(url: URL) -> Date {
        var modificationDate: Date?
        
        do {
            let fileAttribute: [FileAttributeKey : Any] = try FileManager.default.attributesOfItem(atPath: url.path)
            modificationDate = fileAttribute[FileAttributeKey.modificationDate] as! Date
        } catch {
            print(error.localizedDescription)
        }
        
        return modificationDate!
    }
    
    func populateTable(search: String) {
        let markdownFiles = self.readDocuments()
        var noteList = [Note]()
        
        for (markdownPath) in markdownFiles {
            let url = self.getDefaultDocumentsUrl().appendingPathComponent(markdownPath)
            let preview = self.getPreviewText(url: url)
            
            var name = ""
            if (url.pathComponents.count > 0) {
                name = url.pathComponents.last!
            }
        
            let note = Note()
            note.date = self.getModificationDate(url: url)
            note.content = preview
            note.name = name
            note.url = url
            
            if (search.count == 0 || preview.contains(search) || name.contains(search)) {
                noteList.append(note)
            }

        }
        
        notesTableView.notesList = noteList
    }
    
    override func keyUp(with event: NSEvent) {
        // Focus search bar on ESC
        if (event.keyCode == 53) {
            search.becomeFirstResponder()
        }
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
        search.focusRingType = .none
    }
    
    func getDefaultDocumentsUrl() -> URL {
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        return documentsUrl
    }
    
    func makeUniqueFileName(name: String, i: Int = 0) -> URL {
        let defaultUrl = self.getDefaultDocumentsUrl()
        
        var fileUrl = defaultUrl
        fileUrl.appendPathComponent(name + ".md")
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileUrl.path) {
            let j = i + 1
            let newName = "Untitled note" + " " + String(j)
            return self.makeUniqueFileName(name: newName, i: j)
        }
        
        return fileUrl
    }
    
    func readDocuments() -> Array<String> {
        let urlArray: [String] = [""]
        
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let urlArray = try? FileManager.default.contentsOfDirectory(at: directory,
                                                                       includingPropertiesForKeys: [.contentModificationDateKey],
                                                                       options:.skipsHiddenFiles) {
            
            let markdownFiles = urlArray.filter{$0.pathExtension == "md"}
            return markdownFiles.map { url in
                    (
                        url.lastPathComponent,
                        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast)
                }
                .sorted(by: { $0.1 > $1.1 })
                .map { $0.0 }
        }
        
        return urlArray
    }
    
    func selectNullTableRow() {
        self.noteList.selectRowIndexes([0], byExtendingSelection: false)
    }
    
    func writeContent(note: Note, content: String) {
        let fileUrl = self.getDefaultDocumentsUrl().appendingPathComponent(note.name!)
        
        do {
            try content.write(to: fileUrl, atomically: false, encoding: String.Encoding.utf8)
        }
        catch { }
    }
}

