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
    @IBOutlet weak var sidebarWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var notesWidthConstraint: NSLayoutConstraint!
    
    let storage = Storage.sharedInstance()
    public var cloudDriveManager: CloudDriveManager?
    
    override func viewDidLoad() {
        UIApplication.shared.statusBarStyle = MixedStatusBarStyle(normal: .default, night: .lightContent).unfold()
                
        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        
        notesTable.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)
        sidebarTableView.mixedBackgroundColor = MixedColor(normal: 0xf7f5f3, night: 0x313636)
        
        let searchBarTextField = search.value(forKey: "searchField") as? UITextField
        searchBarTextField?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xfafafa)
        
        loadPlusButton()
        initSettingsButton()
        
        search.delegate = self
        search.autocapitalizationType = .none
        
        notesTable.viewDelegate = self
        
        UserDefaultsManagement.fontSize = 17
                
        if storage.noteList.count == 0 {
            storage.initiateCloudDriveSync()
            storage.loadDocuments()
            updateTable() {}
        }
        
        sidebarTableView.sidebar = Sidebar()
        sidebarTableView.reloadData()
        
        guard let pageController = self.parent as? PageViewController else {
            return
        }
        
        pageController.disableSwipe()
        
        self.cloudDriveManager = CloudDriveManager(delegate: self, storage: storage)
        keyValueWatcher()
        
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeScreenBrightness), name: NSNotification.Name.UIScreenBrightnessDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector:#selector(viewWillAppear(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(handleSidebarSwipe))
        swipe.minimumNumberOfTouches = 2
        swipe.delegate = self
        view.addGestureRecognizer(swipe)
        
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        sidebarWidthConstraint.constant = UserDefaultsManagement.sidebarSize
        notesWidthConstraint.constant = view.frame.width - UserDefaultsManagement.sidebarSize
        
        var sRect: CGRect = sidebarTableView.frame
        sRect.size.width = UserDefaultsManagement.sidebarSize
        sidebarTableView.draw(sRect)
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
            
    private func getEVC() -> EditorViewController? {
        if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
            let evc = viewController.viewControllers[0] as? EditorViewController {
            return evc
        }
        
        return nil
    }
        
    func updateTable(search: Bool = false, completion: @escaping () -> Void) {
        let filter = self.search.text!
        
        if !search {
            storage.noteList = storage.sortNotes(noteList: storage.noteList, filter: "")
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
                        isFitInSidebar(note: $0)
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
    
    public func isFitInSidebar(note: Note) -> Bool {
        var type: SidebarItemType? = nil
        var project: Project? = nil
        var sidebarName = ""
        
        if let sidebarItem = getSidebarItem() {
            sidebarName = sidebarItem.name
            type = sidebarItem.type
            project = sidebarItem.project
        }
        
        if type == .Trash && note.isTrash()
            || type == .All && !note.isTrash()
            || type == .Tag && note.tagNames.contains(sidebarName)
            || [.Category, .Label].contains(type) && project != nil && note.project == project
            || type == nil && project == nil && !note.isTrash()
            || project != nil && project!.isRoot && note.project?.parent == project {
            
            return true
        }
        
        return false
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
    
    private var addButton: UIButton?
    
    func loadPlusButton() {
        if let button = getButton() {
            let width = self.view.frame.width
            let height = self.view.frame.height
            
            button.frame = CGRect(origin: CGPoint(x: CGFloat(width - 80), y: CGFloat(height - 80)), size: CGSize(width: 48, height: 48))
            return
        }
        
        let button = UIButton(frame: CGRect(origin: CGPoint(x: self.view.frame.width - 80, y: self.view.frame.height - 80), size: CGSize(width: 48, height: 48)))
        let image = UIImage(named: "plus.png")
        button.setImage(image, for: UIControlState.normal)
        button.tag = 1
        button.tintColor = UIColor(red:0.49, green:0.92, blue:0.63, alpha:1.0)
        self.view.addSubview(button)
        button.addTarget(self, action: #selector(self.newButtonAction), for: .touchDown)
    }
    
    private func getButton() -> UIButton? {
        for sub in self.view.subviews {
            
            if sub.tag == 1 {
                return sub as? UIButton
            }
        }
        
        return nil
    }
    
    func initSettingsButton() {
        let settingsIcon = UIImage(named: "settings.png")
        let tintedSettings = settingsIcon?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        settingsButton.setImage(tintedSettings, for: UIControlState.normal)
        settingsButton.tintColor = UIColor.gray
        settingsButton.addTarget(self, action: #selector(self.openSettings), for: .touchDown)
    }
    
    @objc func newButtonAction() {
        createNote(content: nil)
    }
    
    func createNote(content: String? = nil) {
        var currentProject: Project
        var tag: String?
        
        if let project = storage.getProjects().first {
            currentProject = project
        } else {
            return
        }
        
        if let item = getSidebarItem() {
            if item.type == .Tag {
                tag = item.name
            }
            
            if let project = item.project, !project.isTrash {
                currentProject = project
            }
        }
        
        let note = Note(name: "", project: currentProject)
        note.initURL()
        
        if let tag = tag {
            note.tagNames.append(tag)
        }
        
        if let content = content {
            note.content = NSMutableAttributedString(string: content)
        }
        
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
        viewWillAppear(false)
        loadPlusButton()
        
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
            let evc = viewController.viewControllers[0] as? EditorViewController else { return }
        
        evc.reloadPreview()
    }
    
    @objc func didChangeScreenBrightness() {
        guard UserDefaultsManagement.nightModeType == .brightness else {
            return
        }
        
        guard
            let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
            let evc = viewController.viewControllers[0] as? EditorViewController,
            let vc = pageController.orderedViewControllers[0] as? ViewController else {
            return
        }
        
        let brightness = Float(UIScreen.screens[0].brightness)

        if (UserDefaultsManagement.maxNightModeBrightnessLevel < brightness && NightNight.theme == .night) {
            NightNight.theme = .normal
            UIApplication.shared.statusBarStyle = .default
            
            UserDefaultsManagement.codeTheme = "atom-one-light"
            NotesTextProcessor.hl = nil
            evc.refill()
            
            vc.sidebarTableView.sidebar = Sidebar()
            vc.sidebarTableView.reloadData()
            vc.notesTable.reloadData()
            
            return
        }
        
        if (UserDefaultsManagement.maxNightModeBrightnessLevel > brightness && NightNight.theme == .normal) {
            NightNight.theme = .night
            UIApplication.shared.statusBarStyle = .lightContent
            
            UserDefaultsManagement.codeTheme = "monokai-sublime"
            NotesTextProcessor.hl = nil
            evc.refill()
            
            vc.sidebarTableView.sidebar = Sidebar()
            vc.sidebarTableView.reloadData()
            vc.notesTable.reloadData()
        }
    }
    
    public func getSidebarItem() -> SidebarItem? {
        guard
            let indexPath = sidebarTableView.indexPathForSelectedRow,
            let sidebar = sidebarTableView.sidebar,
            let item = sidebar.getByIndexPath(path: indexPath) else { return nil }
        
        return item
    }
    
    var sidebarWidth: CGFloat = 0
    var width: CGFloat = 0
    
    @objc func handleSidebarSwipe(_ swipe: UIPanGestureRecognizer) {
        guard let pageViewController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageViewController.orderedViewControllers[0] as? ViewController else { return }
        
        let windowWidth = self.view.frame.width
        let translation = swipe.translation(in: vc.notesTable)
        
        if swipe.state == .began {
            self.width = vc.notesTable.frame.size.width
            self.sidebarWidth = vc.sidebarTableView.frame.size.width
            return
        }
        
        let sidebarWidth = self.sidebarWidth + translation.x
        var finSidebarWidth: CGFloat = sidebarWidth
        
        if sidebarWidth < 0 {
            vc.sidebarTableView.frame.size.width = 0
            vc.notesTable.frame.origin.x = 0
            vc.notesTable.frame.size.width = windowWidth
            finSidebarWidth = 0
        }
        
        if sidebarWidth > windowWidth / 2 {
            vc.sidebarTableView.frame.size.width = windowWidth / 2
            vc.notesTable.frame.size.width = windowWidth / 2
            vc.notesTable.frame.origin.x = windowWidth / 2
            finSidebarWidth = windowWidth / 2
        }
        
        if swipe.state == .changed {
            vc.sidebarTableView.frame.size.width = finSidebarWidth
            vc.notesTable.frame.size.width = windowWidth - finSidebarWidth
            vc.notesTable.frame.origin.x = finSidebarWidth
        }
        
        if swipe.state == .ended {
            UserDefaultsManagement.sidebarSize = finSidebarWidth
        }
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            self.view.frame.size.height = UIScreen.main.bounds.height
            self.view.frame.size.height -= keyboardSize.height
            loadPlusButton()
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        self.view.frame.size.height = UIScreen.main.bounds.height
        loadPlusButton()
    }
    
    public func getInsertPosition() -> Int {
        var i = 0
        
        for note in notesTable.notes {
            if note.isPinned {
                i += 1
            }
        }
        
        return i
    }
    
    public func refreshTextStorage(note: Note) {
        DispatchQueue.main.async {
            if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
                let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
                let evc = viewController.viewControllers[0] as? EditorViewController,
                evc.editArea.attributedText.string != note.content.string {
                evc.fill(note: note)
            }
        }
    }
}

