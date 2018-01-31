//
//  ViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource,
    UISearchBarDelegate {

    @IBOutlet weak var search: UISearchBar!
    @IBOutlet var notesTable: NotesTableView!
    
    var notes = [Note]()
    let storage = Storage.instance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        notesTable.dataSource = self
        search.delegate = self
        search.autocapitalizationType = .none
        
        if CoreDataManager.instance.getBy(label: "general") == nil {
            let context = CoreDataManager.instance.context
            let storage = StorageItem(context: context)
            storage.path = UserDefaultsManagement.storageUrl.absoluteString
            storage.label = "general"
            CoreDataManager.instance.save()
        }
        
        if storage.noteList.count == 0 {
            storage.loadDocuments()

            updateTable(filter: "") {
                
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    var filterQueue = OperationQueue.init()
    var filteredNoteList: [Note]?
    var prevQuery: String?
    
    func updateTable(filter: String, search: Bool = false, completion: @escaping () -> Void) {
        if !search, let list = Storage.instance.sortNotes(noteList: storage.noteList) {
            storage.noteList = list
        }
        
        let searchTermsArray = filter.split(separator: " ")
        var source = storage.noteList
        
        if let query = prevQuery, filter.range(of: query) != nil, let unwrappedList = filteredNoteList {
            source = unwrappedList
        } else {
            prevQuery = nil
        }
        
        filteredNoteList =
            source.filter() {
                let searchContent = "\($0.name) \($0.content.string)"
                return (
                    !$0.name.isEmpty
                        && $0.isRemoved == false
                        && (
                            filter.isEmpty
                            || !searchTermsArray.contains(where: { !searchContent.localizedCaseInsensitiveContains($0)
                            })
                    )
                )
        }
        
        if let unwrappedList = filteredNoteList {
            notes = unwrappedList
        }
        
        DispatchQueue.main.async {
            self.notesTable.reloadData()
            
            completion()
        }
        
        prevQuery = filter
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "noteCell", for: indexPath) as! NoteCellView
        
        cell.configure(note: notes[indexPath.row])
        
        return cell
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateTable(filter: searchText, completion: {})
    }
}

