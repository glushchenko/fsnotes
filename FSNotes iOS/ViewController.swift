//
//  ViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight
import Solar

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
        UIApplication.shared.statusBarStyle = MixedStatusBarStyle(normal: .default, night: .lightContent).unfold()
        
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x222222)
        notesTable.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        
        let searchBarTextField = search.value(forKey: "searchField") as? UITextField
        searchBarTextField?.mixedTextColor = MixedColor(normal: 0x0000ff, night: 0xfafafa)
        
        if NightNight.theme == .night {
            search.keyboardAppearance = .dark
        } else {
            search.keyboardAppearance = .default
        }
        
        super.viewDidLoad()

        initNewButton()
        initSettingsButton()
        
        notesTable.dataSource = self
        notesTable.delegate = self
        search.delegate = self
        search.autocapitalizationType = .none
        
        notesTable.separatorStyle = .singleLine
        UserDefaultsManagement.fontSize = 17
        
        let longPressGesture:UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = self
        self.notesTable.addGestureRecognizer(longPressGesture)
        
        if CoreDataManager.instance.getBy(label: "general") == nil {
            let context = CoreDataManager.instance.context
            let storage = StorageItem(context: context)
            storage.path = UserDefaultsManagement.documentDirectory.absoluteString
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // disable swipes
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController else {
            return
        }
        
        pageController.disableSwipe()
        
        // reload last row preview
        if let evc = pageController.orderedViewControllers[1] as? EditorViewController, let note  = evc.note {
            guard let i = notes.index(of: note) else {
                return
            }
            
            notesTable.reloadRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
        }
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return MixedStatusBarStyle(normal: .default, night: .lightContent).unfold()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    var filterQueue = OperationQueue.init()
    var filteredNoteList: [Note]?
    var prevQuery: String?
    var cloudDriveQuery: NSMetadataQuery?
    
    private let workerQueue: OperationQueue = {
        let workerQueue = OperationQueue()
        workerQueue.name = "co.fluder.fsnotes.manager.browserdatasource.workerQueue"
        workerQueue.maxConcurrentOperationCount = 1
        return workerQueue
    }()
        
    func keyValueWatcher() {
        let keyStore = NSUbiquitousKeyValueStore()
        
        NotificationCenter.default.addObserver(self,
           selector: #selector(ubiquitousKeyValueStoreDidChange),
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
        metadataQuery.operationQueue = workerQueue
        
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
        
        var removed = 0
        var added = 0
        
        if let changedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] {
            
            for item in changedMetadataItems {
                let url = item.value(forAttribute: NSMetadataItemURLKey) as! NSURL
                
                let fsName = item.value(forAttribute: NSMetadataItemFSNameKey) as! String
                if url.deletingLastPathComponent?.lastPathComponent == ".Trash" {
                    removed = removed + 1
                    continue
                }
                
                if let note = Storage.instance.getBy(name: fsName) {
                    if let fsDate = note.readModificatonDate(), let noteDate = note.modifiedLocalAt, fsDate == noteDate {
                        continue
                    }
                    
                    _ = note.reload()
                }
                
                var isDownloaded:AnyObject? = nil
                do {
                    try (url as NSURL).getResourceValue(&isDownloaded, forKey: URLResourceKey.ubiquitousItemDownloadingStatusKey)
                } catch _ {}
                
                if isDownloaded as? URLUbiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current {
                    added = added + 1
                }
                
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
                
                DispatchQueue.main.async {
                    if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? EditorViewController, let note = viewController.note, note.name == fsName {
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
        
        if let removedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] {
            
            for item in removedMetadataItems {
                let url = item.value(forAttribute: NSMetadataItemURLKey) as! NSURL
                
                if url.deletingLastPathComponent?.lastPathComponent != ".Trash"{
                    removed = removed + 1
                }
            }
        }
        
        if removed > 0 || added > 0 {
            storage.loadDocuments()
            updateTable(filter: "") {
                print("Table was updated.")
            }
        }
        
        cloudDriveQuery?.enableUpdates()
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
        pageController.switchToEditor()
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
        deleteAction.backgroundColor = UIColor(red:0.93, green:0.31, blue:0.43, alpha:1.0)
        
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
        pin.backgroundColor = UIColor(red:0.24, green:0.59, blue:0.94, alpha:1.0)
        
        return [rename, pin, deleteAction]
    }
    
    private func tableView(_ tableView: UITableView, willDisplay cell: NoteCellView, forRowAt indexPath: IndexPath) {
        cell.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)
        cell.textLabel?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xffffff)
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
        pageController.switchToEditor()
        viewController.fill(note: note)
    }
    
    func createNote(content: String) {
        let note = Note(name: "")
        note.content = NSMutableAttributedString(string: content)
        note.save()
        updateList()
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
        pageController.switchToEditor()
        viewController.fill(note: note)
    }
    
    @objc func openSettings() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let sourceSelectorTableViewController = storyBoard.instantiateViewController(withIdentifier: "settingsViewController") as! SettingsViewController
        let navigationController = UINavigationController(rootViewController: sourceSelectorTableViewController)
        
        navigationController.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: MixedColor(normal: 0x000000, night: 0xfafafa)]
        navigationController.navigationBar.mixedTintColor = MixedColor(normal: 0x0000ff, night: 0xfafafa)
        navigationController.navigationBar.mixedBarTintColor = MixedColor(normal: 0xffffff, night: 0x222222)
        navigationController.navigationBar.mixedBarStyle = MixedBarStyle(normal: .default, night: .blackTranslucent)
        
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @objc func preferredContentSizeChanged() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    @objc func rotated() {
        initNewButton()
    }
}

