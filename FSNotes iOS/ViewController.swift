//
//  ViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class ViewController: UIViewController,
    UITableViewDataSource,
    UITableViewDelegate,
    UISearchBarDelegate,
    UITabBarDelegate,
    UIGestureRecognizerDelegate,
    CloudKitManagerDelegate {

    @IBOutlet weak var search: UISearchBar!
    @IBOutlet var notesTable: NotesTableView!
    @IBOutlet weak var tabBar: UITabBar!
    
    var notes = [Note]()
    let storage = Storage.instance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBar.delegate = self
        notesTable.dataSource = self
        notesTable.delegate = self
        search.delegate = self
        search.autocapitalizationType = .none
        
        notesTable.separatorStyle = .singleLine
        UserDefaultsManagement.fontSize = 16
        
        CloudKitManager.sharedInstance().delegate = self
        
        let longPressGesture:UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = self
        self.notesTable.addGestureRecognizer(longPressGesture)
        
        if CoreDataManager.instance.getBy(label: "general") == nil {
            let context = CoreDataManager.instance.context
            let storage = StorageItem(context: context)
            storage.path = UserDefaultsManagement.storageUrl.absoluteString
            storage.label = "general"
            CoreDataManager.instance.save()
        }

#if os(iOS)
        let storageItem = CoreDataManager.instance.getBy(label: "general")
        storageItem?.path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        CoreDataManager.instance.save()
#endif
        
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "noteCell", for: indexPath) as! NoteCellView
        
        cell.configure(note: notes[indexPath.row])
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let pageController = self.parent as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? EditorViewController else {
            return
        }
        
        let note = notes[indexPath.row]
        viewController.fill(note: note)
        pageController.goToNextPage()
    }
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if item.title == "New" {
            let note = Note(name: "")
            note.save()
            updateList()
            
            guard let pageController = self.parent as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? EditorViewController else {
                return
            }
                        
            viewController.note = note
            pageController.goToNextPage()
            viewController.fill(note: note)
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateTable(filter: searchText, completion: {})
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let name = searchBar.text else {
            return
        }
        
        let note = Note(name: name)
        note.save()
        
        updateList()
        
        guard let pageController = self.parent as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? EditorViewController else {
            return
        }
        
        viewController.note = note
        pageController.goToNextPage()
        viewController.fill(note: note)
    }
    
    @objc func handleLongPress(longPressGesture:UILongPressGestureRecognizer) {
        let p = longPressGesture.location(in: self.notesTable)
        let indexPath = self.notesTable.indexPathForRow(at: p)
        if indexPath == nil {
            print("Long press on table view, not row.")
        }
        else if (longPressGesture.state == UIGestureRecognizerState.began) {
            let alert = UIAlertController.init(title: "Are you sure you want to remove note?", message: "This action cannot be undone.", preferredStyle: .alert)
            
            let remove = UIAlertAction(title: "Remove", style: .destructive) { (alert: UIAlertAction!) -> Void in
                let notes = [self.notes[indexPath!.row]]
                Storage.instance.removeNotes(notes: notes)
                self.updateList()
            }
            let cancel = UIAlertAction(title: "Cancel", style: .default)
            
            alert.addAction(cancel)
            alert.addAction(remove)
            
            present(alert, animated: true, completion:nil)
        }
    }
    
    func updateList() {
        updateTable(filter: search.text!) {
            self.notesTable.reloadData()
        }
    }
    
    func reloadView(note: Note?) {
        DispatchQueue.main.async {
            self.updateList()
            
        }
        
    }
    
    func refillEditArea(cursor: Int?, previewOnly: Bool) {
        //
    }
}

