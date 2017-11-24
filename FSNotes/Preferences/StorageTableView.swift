//
//  StorageTableView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 11/12/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import CoreData

class StorageTableView: NSTableView, NSTableViewDataSource,
NSTableViewDelegate {
    
    var list = [StorageItem]()
    let viewController = NSApplication.shared.windows.first!.contentViewController as! ViewController
    
    override func draw(_ dirtyRect: NSRect) {
        self.dataSource = self
        self.delegate = self
        super.draw(dirtyRect)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return list.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if ((tableColumn?.identifier)!.rawValue == "Label") {
            return list[row].label
        }
        Swift.print(list[row].getPath())
        return list[row].getPath()
    }
    
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        return (list[row].label != "general" && tableColumn?.identifier.rawValue != "Path")
    }
    
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        if (list.indices.contains(row)) {
            guard let label = object as? String else {
                return
            }
            
            guard label != "general" else {
                return
            }
            
            let storage = list[selectedRow]
            storage.label = label
                
            CoreDataManager.instance.save()
        }
        
        self.reload()
    }
    
    func reload() {
        list = CoreDataManager.instance.fetchStorageList()
        reloadData()
        Storage.instance.loadDocuments()
        viewController.notesTableView.reloadData()
    }
    
    func getSelected() -> StorageItem? {
        var storage: StorageItem? = nil
        
        if (list.indices.contains(selectedRow)) {
            storage = list[selectedRow]
        }
        
        return storage
    }

}
