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
    
    private let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
    
    let storage = Storage.sharedInstance()
    public var cloudDriveManager: CloudDriveManager?
    
    public var shouldReloadNotes = false
    
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
        
        notesTable.dataSource = notesTable
        notesTable.delegate = notesTable
        
        sidebarTableView.dataSource = sidebarTableView
        sidebarTableView.delegate = sidebarTableView
        
        UserDefaultsManagement.fontSize = 17
                
        if storage.noteList.count == 0 {
            DispatchQueue.global().async {
                self.storage.initiateCloudDriveSync()
            }
            
            DispatchQueue.global().async {
                self.storage.loadDocuments()
                DispatchQueue.main.async {
                    self.updateTable() {}
                    self.indicator.stopAnimating()
                    self.sidebarTableView.sidebar = Sidebar()
                    self.sidebarTableView.reloadData()
                    self.cloudDriveManager = CloudDriveManager(delegate: self, storage: self.storage)
                }
            }
        }
        
        self.sidebarTableView.sidebar = Sidebar()
        self.sidebarTableView.reloadData()
        
        guard let pageController = self.parent as? PageViewController else {
            return
        }
        
        pageController.disableSwipe()

        keyValueWatcher()
        
        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeScreenBrightness), name: NSNotification.Name.UIScreenBrightnessDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector:#selector(viewWillAppear(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(handleSidebarSwipe))
        swipe.minimumNumberOfTouches = 1
        swipe.delegate = self
        
        view.addGestureRecognizer(swipe)
        //view.dele\
        
        super.viewDidLoad()
        
        self.indicator.color = NightNight.theme == .night ? UIColor.white : UIColor.black
        self.indicator.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 40.0)
        self.indicator.center = self.view.center
        self.self.view.addSubview(indicator)
        self.indicator.bringSubview(toFront: self.view)
        self.indicator.startAnimating()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = gestureRecognizer as? UIPanGestureRecognizer {
            if recognizer.translation(in: self.view).x > 0 || sidebarTableView.frame.width != 0 {
                return true
            }
        }
        return false
    }

    override func viewWillAppear(_ animated: Bool) {
        sidebarWidthConstraint.constant = self.finSidebarWidth
        notesWidthConstraint.constant = view.frame.width - self.finSidebarWidth

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
                self.updateTable() {}
            }
        }
    }
            
    private func getEVC() -> EditorViewController? {
        print(" get evc")
        if let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
            let evc = viewController.viewControllers[0] as? EditorViewController {
            return evc
        }
        
        return nil
    }
        
    public func updateTable(search: Bool = false, completion: @escaping () -> Void) {
        let filter = self.search.text!

        var type: SidebarItemType? = nil
        var terms = filter.split(separator: " ")

        if let sidebarItem = getSidebarItem() {
            type = sidebarItem.type
        }

        if let type = type, type == .Todo {
            terms.append("- [ ]")
        }

        let filteredNoteList =
            storage.noteList.filter() {
                return (
                    !$0.name.isEmpty
                    && (
                        filter.isEmpty && type != .Todo || type == .Todo && (
                            self.isMatched(note: $0, terms: ["- [ ]"])
                                || self.isMatched(note: $0, terms: ["- [x]"])
                            )
                            || self.isMatched(note: $0, terms: terms)
                    ) && (
                        isFitInSidebar(note: $0)
                    )
                )
        }
        
        if !filteredNoteList.isEmpty {
            notesTable.notes = storage.sortNotes(noteList: filteredNoteList, filter: "")
        } else {
            notesTable.notes.removeAll()
        }
        
        DispatchQueue.main.async {
            self.notesTable.reloadData()
            
            completion()
        }
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
            || type == .All && !note.isTrash() && !note.project!.isArchive
            || type == .Tag && note.tagNames.contains(sidebarName)
            || [.Category, .Label].contains(type) && project != nil && note.project == project
            || type == nil && project == nil && !note.isTrash()
            || project != nil && project!.isRoot && note.project?.parent == project
            || type == .Archive && note.project != nil && note.project!.isArchive
            || type == .Todo {
            
            return true
        }
        
        return false
    }

    public func insertRow(note: Note) {
        let i = self.getInsertPosition()

        DispatchQueue.main.async {
            if self.isFitInSidebar(note: note), !self.notesTable.notes.contains(note) {

                self.notesTable.notes.insert(note, at: i)
                self.notesTable.beginUpdates()
                self.notesTable.insertRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
                self.notesTable.reloadRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
                self.notesTable.endUpdates()
            }
        }
    }

    private func isMatched(note: Note, terms: [Substring]) -> Bool {
        for term in terms {
            if note.name.range(of: term, options: .caseInsensitive, range: nil, locale: nil) != nil || note.content.string.range(of: term, options: .caseInsensitive, range: nil, locale: nil) != nil {
                continue
            }

            return false
        }

        return true
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
        note.save()
        
        self.updateTable() {}
        
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? UINavigationController, let evc = viewController.viewControllers[0] as? EditorViewController else {
            return
        }
    
        evc.note = note
        pageController.switchToEditor()
        evc.fill(note: note)
    }
    
    func reloadView(note: Note?) {
        print("reload view")
        DispatchQueue.main.async {
            self.updateTable() {}
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
        button.addTarget(self, action: #selector(self.newButtonAction), for: .touchDown)
        self.view.addSubview(button)

        print("multi add")
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
        
        if let tag = tag {
            note.tagNames.append(tag)
        }
        
        if let content = content {
            note.content = NSMutableAttributedString(string: content)
        }

        note.save(to: note.url, for: .forCreating, completionHandler: nil)
        
        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? UINavigationController, let evc = viewController.viewControllers[0] as? EditorViewController else {
            return
        }
        
        evc.note = note
        pageController.switchToEditor()
        evc.fill(note: note)
        
        self.shouldReloadNotes = true
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
    var start: CFTimeInterval = 0
    var finSidebarWidth: CGFloat = 0

    @objc func handleSidebarSwipe(_ swipe: UIPanGestureRecognizer) {
        guard let pageViewController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
            let vc = pageViewController.orderedViewControllers[0] as? ViewController else { return }
        
        let windowWidth = self.view.frame.width
        let translation = swipe.translation(in: vc.notesTable)
        
        if swipe.state == .began {
            self.start = CACurrentMediaTime()

            self.width = vc.notesTable.frame.size.width
            self.sidebarWidth = vc.sidebarTableView.frame.size.width
            return
        }

        let sidebarWidth = self.sidebarWidth + translation.x
        vc.finSidebarWidth = sidebarWidth
        
        if sidebarWidth < 0 {
            vc.sidebarTableView.frame.size.width = 0
            vc.notesTable.frame.origin.x = 0
            vc.notesTable.frame.size.width = windowWidth
            vc.finSidebarWidth = 0
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

            let end = CACurrentMediaTime()
            guard end - self.start < 0.5 else {
                print(finSidebarWidth)
                UserDefaultsManagement.sidebarSize = finSidebarWidth
                return
            }

            UIView.animate(withDuration: 0.1, animations: {
                if translation.x > 0 {
                    var sidebarWidth = windowWidth / 2

                    if UserDefaultsManagement.sidebarSize > 0 && sidebarWidth > UserDefaultsManagement.sidebarSize {
                        sidebarWidth = UserDefaultsManagement.sidebarSize
                    }

                    vc.sidebarTableView.frame.size.width = sidebarWidth
                    vc.notesTable.frame.size.width = windowWidth - sidebarWidth
                    vc.notesTable.frame.origin.x = sidebarWidth
                    vc.finSidebarWidth = sidebarWidth
                }

                if translation.x < 0 {
                    vc.sidebarTableView.frame.size.width = 0
                    vc.notesTable.frame.origin.x = 0
                    vc.notesTable.frame.size.width = windowWidth
                    vc.finSidebarWidth = 0
                }
            })
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
            guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
                let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
                let evc = viewController.viewControllers[0] as? EditorViewController
            else { return }
            
            evc.fill(note: note)
        }
    }
}

