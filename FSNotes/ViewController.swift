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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.delegate = self
        search.delegate = self
        
        noteList.dataSource = self
        noteList.delegate = self
        
        self.populateTable(search: "")
        //textView.textContainerInset = NSMakeSize(0, 5);
        
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
        print(textView.string)
    }
    
    override func controlTextDidChange(_ obj: Notification) {

        self.notesItem.removeAll();
        self.populateTable(search: search.stringValue)
        
        noteList.reloadData()
    }
    
    @IBAction func demo(_ sender: NSTextField) {
        print(222)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window!.title = "FSNotes"
    }
    
    // populate table
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return self.notesItem[row].name! + "\n\n" + self.notesItem[row].content!
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
            
            //myTable.hideRows(at: <#T##IndexSet#>, withAnimation: <#T##NSTableView.AnimationOptions#>)
        }
    }
    
    func populateTable(search: String) {
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        //self.notes = ["documentsUrl", "sss"];
        
        do {
            let keys = [URLResourceKey.isDirectoryKey, URLResourceKey.localizedNameKey, URLResourceKey.contentModificationDateKey]
            
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: keys, options: [])
            
            // if you want to filter the directory contents you can do like this:
            var markdownFiles = directoryContents.filter{$0.pathExtension == "md"}
            
            var noteList = [Note]()
            for (markdownPath) in markdownFiles {
                
                //print(markdownFiles)
                var modDate = self.getModificationDate(url: markdownPath)
                var preview = self.getPreviewText(url: markdownPath)
                
                
                var note = Note()
                note.date = modDate
                note.content = preview
                note.name = markdownPath.pathComponents.last
                
                if (search.count == 0 || preview.contains(search)) {
                    noteList.append(note)
                }
                
                
            }
            self.notesItem = noteList
            
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
}

