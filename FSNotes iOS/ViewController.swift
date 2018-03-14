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
    UIGestureRecognizerDelegate {

    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var search: UISearchBar!
    @IBOutlet var notesTable: NotesTableView!
    
    var notes = [Note]()
    let storage = Storage.instance
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initNewButton()
        initSettingsButton()
        
        notesTable.dataSource = self
        notesTable.delegate = self
        search.delegate = self
        search.autocapitalizationType = .none
        
        notesTable.separatorStyle = .singleLine
        UserDefaultsManagement.fontSize = 16
        
        let longPressGesture:UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = self
        self.notesTable.addGestureRecognizer(longPressGesture)
        
        if CoreDataManager.instance.getBy(label: "general") == nil {
            let context = CoreDataManager.instance.context
            let storage = StorageItem(context: context)
            storage.path = FileManager.default.url(forUbiquityContainerIdentifier: nil)!.appendingPathComponent("Documents").absoluteString
            storage.label = "general"
            CoreDataManager.instance.save()
        }
        
        if storage.noteList.count == 0 {
            storage.loadDocuments()

            updateTable(filter: "") {
                
            }
        }
        
        guard let pageController = self.parent as? PageViewController else {
            return
        }
        
        pageController.disableSwipe()
        
        cloudDriveWatcher()
        keyValueWatcher()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    var filterQueue = OperationQueue.init()
    var filteredNoteList: [Note]?
    var prevQuery: String?
    var cloudDriveQuery: NSMetadataQuery?
    
    func keyValueWatcher() {
        let keyStore = NSUbiquitousKeyValueStore()
        
        NotificationCenter.default.addObserver(self,
           selector: #selector(
            ViewController.ubiquitousKeyValueStoreDidChange),
           name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
           object: keyStore)
        
        keyStore.synchronize()
    }
    
    @objc func ubiquitousKeyValueStoreDidChange(notification: NSNotification) {
        if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            let keyStore = NSUbiquitousKeyValueStore()
            for key in keys {
                if let isPinned = keyStore.object(forKey: key) as? Bool, let note = Storage.instance.getBy(name: key) {
                    note.isPinned = isPinned
                }
            }
            
            DispatchQueue.main.async {
                self.updateList()
            }
        }
    }
    
    func cloudDriveWatcher() {
        let metadataQuery = NSMetadataQuery()
        cloudDriveQuery = metadataQuery
        cloudDriveQuery?.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        cloudDriveQuery?.predicate = NSPredicate(value: true)
        cloudDriveQuery?.enableUpdates()
        cloudDriveQuery?.start()
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(handleMetadataQueryUpdates), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)
    }
    
    @objc func handleMetadataQueryUpdates(notification: NSNotification) {
        cloudDriveQuery?.disableUpdates()
        
        if let changedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] {
            for item in changedMetadataItems {
                let url = item.value(forAttribute: NSMetadataItemURLKey) as! NSURL

                if let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url as URL) {
                    for conflict in conflicts {                        
                        guard let localizedName = conflict.localizedName else {
                            continue
                        }
                        
                        let url = URL(fileURLWithPath: localizedName)
                        let ext = url.pathExtension
                        let name = url.deletingPathExtension().lastPathComponent
                        
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
                        
                        let documents = UserDefaultsManagement.documentDirectory
                        let to = documents.appendingPathComponent(conflictName)
                        
                        do {
                            try FileManager.default.copyItem(at: conflict.url, to: to)
                        } catch {
                            print(error)
                        }
                        
                        conflict.isResolved = true
                    }
                }
                
                if !isMetadataItemDownloaded(item: item) {
                    let fsName = item.value(forAttribute: NSMetadataItemFSNameKey) as! String
                    
                    if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? EditorViewController, let note = viewController.note, note.name == fsName {
                        
                        note.reloadContent()
                        viewController.fill(note: note)
                    }
                }
            }
        }
        
        if let addedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            for item in addedMetadataItems {
                let url = item.value(forAttribute: NSMetadataItemURLKey) as! NSURL
                
                if FileManager.default.isUbiquitousItem(at: url as URL) {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url as URL)
                }
            }
        }
        
        storage.loadDocuments()
        updateTable(filter: "") {}
        
        cloudDriveQuery?.enableUpdates()
    }
    
    func isMetadataItemDownloaded(item : NSMetadataItem) -> Bool {
        if item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String == NSMetadataUbiquitousItemDownloadingStatusCurrent {
            return true
        } else {
            return false
        }
    }
    
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
        return 75
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
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete", handler: { (action , indexPath) -> Void in
            
            let notes = [self.notes[indexPath.row]]
            Storage.instance.removeNotes(notes: notes) {
                DispatchQueue.main.async {
                    self.updateList()
                }
            }
        })
        deleteAction.backgroundColor = UIColor.red
        
        let rename = UITableViewRowAction(style: .default, title: "Rename", handler: { (action , indexPath) -> Void in
            
            let alertController = UIAlertController(title: "Rename note:", message: nil, preferredStyle: .alert)
            
            alertController.addTextField { (textField) in
                let note = self.notes[indexPath.row]
                textField.placeholder = "Enter note name"
                textField.attributedText = NSAttributedString(string: note.title)
            }
            
            let confirmAction = UIAlertAction(title: "Ok", style: .default) { (_) in
                let name = alertController.textFields?[0].text
                let note = self.notes[indexPath.row]
                note.rename(newName: name!)
                DispatchQueue.main.async {
                    self.updateList()
                }
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
            
            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)
            
            self.present(alertController, animated: true, completion: nil)
            
        })
        rename.backgroundColor = UIColor.gray
        
        let note = self.notes[indexPath.row]
        let pin = UITableViewRowAction(style: .default, title: note.isPinned ? "UnPin" : "Pin", handler: { (action , indexPath) -> Void in
            
            if note.isPinned {
                note.removePin()
            } else {
                note.addPin()
            }
            
            DispatchQueue.main.async {
                self.updateList()
            }
        })
        pin.backgroundColor = UIColor.blue
        
        return [pin, deleteAction, rename]
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateTable(filter: searchText, completion: {})
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let name = searchBar.text, name.count > 0 else {
            searchBar.endEditing(true)
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
                Storage.instance.removeNotes(notes: notes) {
                    DispatchQueue.main.async {
                        self.updateList()
                    }
                }
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
        DispatchQueue.main.async {
            guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? EditorViewController else {
                return
            }
        
            if let note = viewController.note {
                viewController.fill(note: note)
            }
        }
    }
    
    func initNewButton() {
        let button = UIButton(frame: CGRect(origin: CGPoint(x: self.view.frame.width - 80, y: self.view.frame.height - 80), size: CGSize(width: 48, height: 48)))
        let image = UIImage(named: "plus.png")
        button.setImage(image, for: UIControlState.normal)
        button.tintColor = UIColor(red: 76/255, green: 217/255, blue: 100/255, alpha: 1)
        self.view.addSubview(button)
        button.addTarget(self, action: #selector(self.makeNew), for: .touchDown)
    }
    
    func initSettingsButton() {
        let settingsIcon = UIImage(named: "settings.png")
        let tintedSettings = settingsIcon?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        settingsButton.setImage(tintedSettings, for: UIControlState.normal)
        settingsButton.tintColor = UIColor.gray
        settingsButton.addTarget(self, action: #selector(self.openSettings), for: .touchDown)
    }
    
    @objc func makeNew() {
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
    
    @objc func openSettings() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let sourceSelectorTableViewController = storyBoard.instantiateViewController(withIdentifier: "settingsViewController") as! SettingsViewController
        let navigationController = UINavigationController(rootViewController: sourceSelectorTableViewController)
        
        self.present(navigationController, animated: true, completion: nil)
    }
}

