//
//  ViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/20/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTextViewDelegate,
    NSTextFieldDelegate,
    NSTableViewDataSource,
    NSTableViewDelegate {
    
    var notesItem = [Note]()
    
    @IBOutlet weak var noteList: NSTableView!
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var search: NSTextField!
    @IBOutlet weak var notesTableView: NotesTableView!
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window!.title = "FSNotes"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.delegate = self
        search.delegate = self
        
        noteList.dataSource = self
        noteList.delegate = self
        
        self.populateTable(search: "")
        textView.string = notesItem[0].content!
        
        let font = NSFont(name: "Source Code Pro", size: 12)
        noteList.cell?.font = font
        textView.font = font
        
        search.becomeFirstResponder()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func textDidChange(_ notification: Notification) {
        if (notesItem.indices.contains(noteList.selectedRow)) {
            let note = notesItem[noteList.selectedRow]
            let content = textView.string
            
            note.content = content
            writeContent(note: note, content: content)
            populateTable(search:"")
            noteList.reloadData()
            noteList.scrollRowToVisible(0)
            selectNullTableRow()
        }

    }
    
    override func controlTextDidChange(_ obj: Notification) {
        
        self.notesItem.removeAll();
        self.populateTable(search: search.stringValue)
        
        if (self.notesItem.count > 0) {
            textView.string = self.notesItem[0].content!
            self.selectNullTableRow()
        }
        print("changed")
        noteList.reloadData()
    }
    
    @IBAction func makeNote(_ sender: NSTextField) {
        let note = Note()
        note.name = search.stringValue
        note.content = ""
        
        let fileUrl = self.makeUniqueFileName(name: search.stringValue)
        
        let someText = ""
        
        do {
            try someText.write(to: fileUrl, atomically: false, encoding: String.Encoding.utf8)
        }
        catch { }
        
        self.populateTable(search: "")
        noteList.reloadData()
        self.selectNullTableRow()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        print(self.notesItem.count)
        return self.notesItem.count
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
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let myTable = notification.object as? NSTableView {
            // we create an [Int] array from the index set
            myTable.selectedRowIndexes.map {
                textView.string = self.notesItem[$0].content!
            }
        }
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
            
            if (search.count == 0 || preview.contains(search) || name.contains(search)) {
                noteList.append(note)
            }

        }
        
        self.notesItem = noteList
        notesTableView.notesList = noteList
    }
    
    override func keyUp(with event: NSEvent) {
        /**
         * Focus search bar on ESC
         */
        if (event.keyCode == 53) {
            search.becomeFirstResponder()
        }
        
        /**
         * Focus notes lsit on down arrow
         */
        if (event.keyCode == 125) {
            
        }
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
        search.focusRingType = .none
        
        //print("1")
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = noteList.makeView(withIdentifier: tableColumn!.identifier, owner: nil) as? NoteCellView
        {
            cell.preview.stringValue = notesItem[row].content!
            cell.name.stringValue = notesItem[row].name!            
            return cell
        }
        return NoteCellView();
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let myCustomView = NoteRowView()
        return myCustomView
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
    
    func tableView(_ tableView: NSTableView, didRemove rowView: NSTableRowView, forRow row: Int) {
        print(row)
    }

}

