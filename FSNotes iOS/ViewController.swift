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

class ViewController: UIViewController, UISearchBarDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var search: UISearchBar!
    @IBOutlet var notesTable: NotesTableView!
    @IBOutlet weak var sidebarTableView: SidebarTableView!
    
    let storage = Storage.sharedInstance()
    
    override func viewDidLoad() {        
        UIApplication.shared.statusBarStyle = MixedStatusBarStyle(normal: .default, night: .lightContent).unfold()
                
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        notesTable.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        
        let searchBarTextField = search.value(forKey: "searchField") as? UITextField
        searchBarTextField?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xfafafa)
        
        initNewButton()
        initSettingsButton()
        
        search.delegate = self
        search.autocapitalizationType = .none
        
        notesTable.viewDelegate = self
        ///notesTable.separatorStyle = .singleLine
        
        UserDefaultsManagement.fontSize = 17
                
        if storage.noteList.count == 0 {
            storage.loadDocuments()
            updateTable() {}
        }
        
        sidebarTableView.sidebar = Sidebar()
        print("sidebar data attached")
        
        sidebarTableView.reloadData()
        
        guard let pageController = self.parent as? PageViewController else {
            return
        }
        
        pageController.disableSwipe()
        
        cloudDriveWatcher()
        keyValueWatcher()
        
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeScreenBrightness), name: NSNotification.Name.UIScreenBrightnessDidChange, object: nil)
        
        let swipe = UIPanGestureRecognizer(target: notesTable, action: #selector(notesTable.handleSwipe))
        swipe.delegate = self
        view.addGestureRecognizer(swipe)
        
        //sidebarTableView.frame.size.width = 100
        //print()
        //sidebarTableView.frame.origin.y = 0
        print(sidebarTableView.frame.origin.x)
        print(sidebarTableView.frame.origin.y)
        print(sidebarTableView.frame.size.width)
        print(sidebarTableView.frame.size.height)
        
        //sidebarTableView.load
        
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // load keyboard color
        if NightNight.theme == .night {
            search.keyboardAppearance = .dark
        } else {
            search.keyboardAppearance = .default
        }
        
        // disable swipes
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController else {
            return
        }
        
        pageController.disableSwipe()
        
        // reload last row preview
        if let vc = pageController.orderedViewControllers[1] as? UINavigationController, let evc = vc.viewControllers[0] as? EditorViewController, let note  = evc.note {
            
            guard let i = notesTable.notes.index(of: note) else {
                return
            }
            
            notesTable.reloadRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
        }
        
        sidebarTableView.draw(sidebarTableView.frame)
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
                if let isPinned = keyStore.object(forKey: key) as? Bool, let note = storage.getBy(name: key) {
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
                
                if let note = storage.getBy(name: fsName) {
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
                        
                        do {
                            if let to = documents?.appendingPathComponent(conflictName) {
                                try FileManager.default.copyItem(at: conflict.url, to: to)
                            }
                        } catch {
                            print(error)
                        }
                        
                        conflict.isResolved = true
                    }
                }
                
                DispatchQueue.main.async {
                    if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? UINavigationController, let evc = viewController.viewControllers[0] as? EditorViewController, let note = evc.note, note.name == fsName {
                        evc.fill(note: note)
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
            updateTable() {
                print("Table was updated.")
            }
        }
        
        cloudDriveQuery?.enableUpdates()
    }
        
    func updateTable(search: Bool = false, completion: @escaping () -> Void) {
        print("update")
        
        let filter = self.search.text!
        
        var type: SidebarItemType? = nil
        var project: Project? = nil
        var sidebarName = ""
        
        if let sidebarItem = getSidebarItem() {
            sidebarName = sidebarItem.name
            type = sidebarItem.type
            project = sidebarItem.project
        }
        
        if !search, let list = storage.sortNotes(noteList: storage.noteList) {
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
                    ) && (
                        type == .Trash && $0.isTrash()
                            || type == .All && !$0.isTrash()
                            || type == .Tag && $0.tagNames.contains(sidebarName)
                            || [.Category, .Label].contains(type) && project != nil && $0.project == project
                            || type == nil && project == nil && !$0.isTrash()
                            || project != nil && project!.isRoot && $0.project?.parent == project
                    )
                )
        }
        
        if let unwrappedList = filteredNoteList {
            notesTable.notes = unwrappedList
        }
        
        DispatchQueue.main.async {
            self.notesTable.reloadData()
            
            completion()
        }
        
        prevQuery = filter
    }
    

    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateTable(completion: {})
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let name = searchBar.text, name.count > 0 else {
            searchBar.endEditing(true)
            return
        }
        guard let project = storage.getProjects().first else { return }
        
        search.text = ""
        
        let note = Note(name: name, project: project)
        note.initURL()
        note.save()
        
        updateList()
        
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? UINavigationController, let evc = viewController.viewControllers[0] as? EditorViewController else {
            return
        }
    
        evc.note = note
        pageController.switchToEditor()
        evc.fill(note: note)
    }
    
    func createNote(content: String) {
        guard let project = storage.getProjects().first else { return }
        
        let note = Note(name: "", project: project)
        note.initURL()
        note.content = NSMutableAttributedString(string: content)
        note.save()
        updateList()
    }

    func updateList() {
        updateTable() {
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
            guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? UINavigationController, let evc = viewController.viewControllers[0] as? EditorViewController else {
                return
            }
        
            if let note = evc.note {
                evc.fill(note: note)
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
        guard let project = storage.getProjects().first else { return }
        
        let note = Note(name: "", project: project)
        note.initURL()
        note.save()
        updateList()
        
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? UINavigationController, let evc = viewController.viewControllers[0] as? EditorViewController else {
            return
        }
        
        evc.note = note
        pageController.switchToEditor()
        evc.fill(note: note)
    }
    
    @objc func openSettings() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let sourceSelectorTableViewController = storyBoard.instantiateViewController(withIdentifier: "settingsViewController") as! SettingsViewController
        let navigationController = UINavigationController(rootViewController: sourceSelectorTableViewController)
                
        self.present(navigationController, animated: true, completion: nil)
    }
    
    @objc func preferredContentSizeChanged() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    @objc func rotated() {
        initNewButton()
    }
    
    @objc func didChangeScreenBrightness() {
        guard UserDefaultsManagement.nightModeType == .brightness else {
            return
        }
        
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
            let evc = viewController.viewControllers[0] as? EditorViewController else {
            return
        }
        
        let brightness = Float(UIScreen.screens[0].brightness)

        if (UserDefaultsManagement.maxNightModeBrightnessLevel < brightness && NightNight.theme == .night) {
            NightNight.theme = .normal
            UIApplication.shared.statusBarStyle = .default
            
            UserDefaultsManagement.codeTheme = "atom-one-light"
            NotesTextProcessor.hl = nil
            evc.refill()
            
            return
        }
        
        if (UserDefaultsManagement.maxNightModeBrightnessLevel > brightness && NightNight.theme == .normal) {
            NightNight.theme = .night
            UIApplication.shared.statusBarStyle = .lightContent
            
            UserDefaultsManagement.codeTheme = "monokai-sublime"
            NotesTextProcessor.hl = nil
            evc.refill()
        }
    }
    
    private func getSidebarItem() -> SidebarItem? {
        guard
            let indexPath = sidebarTableView.indexPathForSelectedRow,
            let sidebar = sidebarTableView.sidebar,
            let item = sidebar.getByIndexPath(path: indexPath) else { return nil }
        
        return item
    }
}

