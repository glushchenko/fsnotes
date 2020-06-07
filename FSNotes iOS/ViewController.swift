//
//  ViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight
import LocalAuthentication

class ViewController: UIViewController, UISearchBarDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var preHeaderView: UIView!
    @IBOutlet weak var currentFolder: UILabel!
    @IBOutlet weak var folderCapacity: UILabel!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var search: UISearchBar!
    @IBOutlet weak var searchCancel: UIButton!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var searchView: UIView!
    @IBOutlet weak var notesTable: NotesTableView!
    @IBOutlet weak var sidebarTableView: SidebarTableView!

    @IBOutlet weak var leftPreSafeArea: UIView!
    @IBOutlet weak var rightPreSafeArea: UIView!

    @IBOutlet weak var leftPreHeader: UIView!
    @IBOutlet weak var rightPreHeader: UIView!

    public var indicator: UIActivityIndicatorView?

    public var storage = Storage.shared()
    public var cloudDriveManager: CloudDriveManager?

    private let searchQueue = OperationQueue()
    private let metadataQueue = OperationQueue()
    private var delayedInsert: Note?

    private var filteredNoteList: [Note]?
    private var maxSidebarWidth = CGFloat(0)
    private var accessTime = DispatchTime.now()

    public var is3DTouchShortcut = false
    public var isActiveTableUpdating = false

    private var queryDidFinishGatheringObserver : Any?
    private var isBackground: Bool = false

    public var shouldReturnToControllerIndex: Int = 0
    public var selectedProjects: [Project]?

    // Swipe animation from handleSidebarSwipe
    private var sidebarWidth: CGFloat = 0

    override func viewWillAppear(_ animated: Bool) {
        loadSidebarState()
        loadPreSafeArea()
        
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        if nil == Storage.shared().getRoot() {
            let alert = UIAlertController(title: "Storage not found", message: "Please enable iCloud Drive for this app and try again!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .destructive, handler: { action in
                exit(0)
            }))
            self.present(alert, animated: true, completion: nil)
        }

        super.viewDidAppear(animated)
    }

    override func viewDidLoad() {
        //NightNight.theme = .normal
        NightNight.theme = .night

        configureUI()
        configureNotifications()
        configureGestures()

        loadNotesTable()
        loadSidebar()
        preLoadProjectsData()

//        leftPreSafeArea.mixedBackgroundColor =
//            MixedColor(
//                normal: UIColor(red: 0.27, green: 0.51, blue: 0.64, alpha: 1.00),
//                night: UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.00)
//            )

        rightPreSafeArea.mixedBackgroundColor =
            MixedColor(
                normal: UIColor(red: 0.27, green: 0.51, blue: 0.64, alpha: 1.00),
                night: UIColor(red: 0.18, green: 0.17, blue: 0.20, alpha: 1.00)
            )

        preHeaderView.mixedBackgroundColor =
            MixedColor(
                normal: UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00),
                night: UIColor(red: 0.28, green: 0.27, blue: 0.31, alpha: 1.00)
            )

        leftPreHeader.mixedBackgroundColor =
            MixedColor(
                normal: UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00),
                night: UIColor(red: 0.28, green: 0.27, blue: 0.31, alpha: 1.00)
            )

        rightPreHeader.mixedBackgroundColor =
            MixedColor(
                normal: UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00),
                night: UIColor(red: 0.28, green: 0.27, blue: 0.31, alpha: 1.00)
            )

        loadPreSafeArea()

        super.viewDidLoad()
    }

    public func getLeftInset() -> CGFloat {
        let left = UIApplication.shared.windows.first?.safeAreaInsets.left ?? 0

        return left
    }

    public func loadSidebarState() {
        if UserDefaultsManagement.sidebarIsOpened {
            notesTable.frame.origin.x = getLeftInset() + maxSidebarWidth
        } else {
            notesTable.frame.origin.x = getLeftInset()
        }
    }

    public func loadNotesFrame() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        let top = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
        let bottom = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
        let right = UIApplication.shared.windows.first?.safeAreaInsets.right ?? 0
        let left = UIApplication.shared.windows.first?.safeAreaInsets.left ?? 0
        let navHeight: CGFloat = 45

        let topInset = top + navHeight
        let leftInset = left

        print("top: \(top)")
        print("bottom: \(bottom)")
        print("left: \(left)")
        print("right: \(right)")

        notesTable.translatesAutoresizingMaskIntoConstraints = true
        sidebarTableView.translatesAutoresizingMaskIntoConstraints = true

        notesTable.frame.origin.x = leftInset
        notesTable.frame.origin.y = topInset
        notesTable.frame.size.width = screenWidth - left - right - navHeight
        notesTable.frame.size.height = screenHeight - top - navHeight

        sidebarTableView.frame.origin.x = leftInset
        sidebarTableView.frame.origin.y = topInset
        sidebarTableView.frame.size.width = screenWidth - left - right
        sidebarTableView.frame.size.height = screenHeight - top

        loadPreSafeArea()
        loadSidebarState()
    }

    public func loadPreSafeArea() {
        if UserDefaultsManagement.sidebarIsOpened {
            // blue/black pre safe area
            leftPreSafeArea.mixedBackgroundColor =
                MixedColor(
                    normal: UIColor(red: 0.27, green: 0.51, blue: 0.64, alpha: 1.00),
                    night: UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.00)
                )

            notesTable.frame.size.width = self.view.frame.width - self.getLeftInset() - maxSidebarWidth
        } else {
            leftPreSafeArea.mixedBackgroundColor =
                MixedColor(
                    normal: .white,
                    night: UIColor(red: 0.18, green: 0.17, blue: 0.20, alpha: 1.00)
                )

            notesTable.frame.size.width = self.view.frame.width - self.getLeftInset()
        }
    }

    public func preLoadProjectsData() {
        DispatchQueue.global(qos: .userInteractive).async {
            let storage = self.storage

            guard let mainProject = storage.getDefault() else { return }
            print("1. Initial data loading finished")

            let projectsPoint = Date()
            storage.assignNonRootProjects(project: mainProject)
            print("2. Projects tree loading finished in \(projectsPoint.timeIntervalSinceNow * -1) seconds")

            let loadAllPoint = Date()
            storage.loadAllProjectsExceptDefault()
            print("3. All notes data loading finished in \(loadAllPoint.timeIntervalSinceNow * -1) seconds")

            /*
             Add and remove default project notes not in cache
             */
            let cachePoint = Date()
            self.loadCacheDiff()
            print("4. Cache diff finished in \(cachePoint.timeIntervalSinceNow * -1) seconds")

            let tagsPoint = Date()
            storage.loadAllTags()
            print("5. Tags loading finished in \(tagsPoint.timeIntervalSinceNow * -1) seconds")

            self.startCloudDriveSyncEngine()
            self.cacheSharingExtensionProjects()

            DispatchQueue.main.async {
                if UserDefaultsManagement.inlineTags {
                    self.sidebarTableView.sidebar = Sidebar()
                    self.sidebarTableView.reloadProjectsSection()
                    self.sidebarTableView.loadAllTags()
                } else {
                    self.reloadSidebar()
                }
            }
        }
    }

    public func configureUI() {
        self.metadataQueue.qualityOfService = .userInteractive

        if UserDefaultsManagement.nightModeType == .system {
            if #available(iOS 12.0, *) {
                if traitCollection.userInterfaceStyle == .dark {
                    NightNight.theme = .night
                } else {
                    NightNight.theme = .normal
                }
            }
        }

        self.indicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.whiteLarge)

        self.searchButton.setImage(UIImage(named: "search_white"), for: .normal)
        self.settingsButton.setImage(UIImage(named: "more_white"), for: .normal)

        //self.preHeaderView.mixedBackgroundColor = Colors.Header
        self.headerView.mixedBackgroundColor = Colors.Header
        self.searchView.mixedBackgroundColor = Colors.Header

        self.search.mixedBackgroundColor = Colors.Header
        self.search.mixedBarTintColor = Colors.Header
        self.search.returnKeyType = .go
         if let textFieldInsideSearchBar = self.search.value(forKey: "searchField") as? UITextField,
               let glassIconView = textFieldInsideSearchBar.leftView as? UIImageView {
                   glassIconView.image = glassIconView.image?.withRenderingMode(.alwaysTemplate)
                   glassIconView.tintColor = .white
           }

        self.folderCapacity.mixedTextColor = Colors.titleText
        self.currentFolder.mixedTextColor = Colors.titleText
        self.currentFolder.isUserInteractionEnabled = true
        self.currentFolder.addGestureRecognizer(UITapGestureRecognizer(target: self.notesTable, action: #selector(self.notesTable.toggleSelectAll)))

        self.searchCancel.mixedTintColor = Colors.buttonText
        search.keyboardAppearance = NightNight.theme == .night ? .dark : .default

        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x47444e)
        notesTable.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)

        let searchBarTextField = search.value(forKey: "searchField") as? UITextField
        searchBarTextField?.mixedTextColor = MixedColor(normal: 0xfafafa, night: 0xfafafa)

        loadPlusButton()

        search.delegate = self
        search.autocapitalizationType = .none

        notesTable.viewDelegate = self

        if #available(iOS 11.0, *) {
            notesTable.dragInteractionEnabled = true
            notesTable.dragDelegate = notesTable

            sidebarTableView.dropDelegate = sidebarTableView
        }

        notesTable.dataSource = notesTable
        notesTable.delegate = notesTable
        notesTable.layer.zPosition = 100
        notesTable.rowHeight = UITableView.automaticDimension
        notesTable.estimatedRowHeight = 160

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(togglseSearch), for: .valueChanged)

        notesTable.refreshControl = refreshControl

        if let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController {
            bvc.disableSwipe()
        }
    }

    public func startCloudDriveSyncEngine() {
        self.cloudDriveManager = CloudDriveManager(delegate: self, storage: self.storage)

        if let cdm = self.cloudDriveManager {
            self.queryDidFinishGatheringObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: cdm.metadataQuery, queue: self.metadataQueue) { notification in

                cdm.queryDidFinishGathering(notification: (notification as NSNotification))

                NotificationCenter.default.removeObserver(self.queryDidFinishGatheringObserver as Any, name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: nil)

                NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidUpdate, object: cdm.metadataQuery, queue: self.metadataQueue) { notification in

                    UIApplication.shared.runInBackground({
                        cdm.handleMetadataQueryUpdates(notification: notification as NSNotification)
                    })
                }
            }

            self.cloudDriveManager?.metadataQuery.start()
        }
    }

    public func cacheSharingExtensionProjects() {
        UserDefaultsManagement.projects =
            storage.getProjects()
                .filter({ !$0.isTrash })
                .compactMap({ $0.url })
    }

    private func loadCacheDiff() {
        if let diff = storage.checkCacheDiff() {
            if diff.0.count > 0 {
                for note in diff.0 {
                    storage.noteList.removeAll(where: { $0 == note })
                }
            }

            if diff.1.count > 0 {
                for note in diff.1 {
                    storage.noteList.append(note)
                }
            }

            UserDefaultsManagement.isCheckedCacheDiff = true

            DispatchQueue.main.async {
                self.notesTable.removeRows(notes: diff.0)
                self.notesTable.insertRows(notes: diff.1)
                self.notesTable.reloadRows(notes: diff.2)
            }
        }
    }

    public func reloadSidebar(select project: Project? = nil) {
        DispatchQueue.main.async {
            if !UserDefaultsManagement.inlineTags {
                self.sidebarTableView.sidebar = Sidebar()
            }

            self.maxSidebarWidth = self.calculateLabelMaxWidth()
            self.sidebarTableView.reloadData()

            let items = self.sidebarTableView.sidebar.items[1]
            guard let selected = project, let i = items.lastIndex(where: { $0.project == selected }) else { return }

            let indexPath = IndexPath(row: i, section: 1)
            self.sidebarTableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            self.sidebarTableView.tableView(self.sidebarTableView, didSelectRowAt: indexPath)
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = gestureRecognizer as? UIPanGestureRecognizer {
            if recognizer.translation(in: self.view).x > 0 && !UserDefaultsManagement.sidebarIsOpened
            || recognizer.translation(in: self.view).x < 0 &&
                UserDefaultsManagement.sidebarIsOpened {
                return true
            }
        }
        return false
    }

    @IBAction func openSearchView(_ sender: Any) {
        self.toggleSearchView()
    }

    @IBAction func hideSearchView(_ sender: Any) {
        self.toggleSearchView()
    }

    @IBAction func bulkEditing(_ sender: Any) {
        if notesTable.isEditing {
            self.settingsButton.setImage(UIImage(named: "more_white.png"), for: .normal)

            if let selectedRows = notesTable.selectedIndexPaths {
                var notes = [Note]()
                for indexPath in selectedRows {
                    if notesTable.notes.indices.contains(indexPath.row) {
                        let note = notesTable.notes[indexPath.row]
                        notes.append(note)
                    }
                }

                self.notesTable.selectedIndexPaths = nil
                self.notesTable.actionsSheet(notes: notes, presentController: self)
            } else {
                self.notesTable.allowsMultipleSelectionDuringEditing = false
                self.notesTable.setEditing(false, animated: true)
            }
        } else {
            notesTable.allowsMultipleSelectionDuringEditing = true
            notesTable.setEditing(true, animated: true)
            self.settingsButton.setImage(UIImage(named: "done_white.png"), for: .normal)
        }
    }

    public func openSettings() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let sourceSelectorTableViewController = storyBoard.instantiateViewController(withIdentifier: "settingsViewController") as! SettingsViewController
        let navigationController = UINavigationController(rootViewController: sourceSelectorTableViewController)

        self.present(navigationController, animated: true, completion: nil)
    }


    public func configureNotifications() {
        let keyStore = NSUbiquitousKeyValueStore()

        NotificationCenter.default.addObserver(self, selector: #selector(ubiquitousKeyValueStoreDidChange), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: keyStore)

        keyStore.synchronize()

        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: UIContentSizeCategory.didChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector:#selector(willExitForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(didChangeScreenBrightness), name: UIScreen.brightnessDidChangeNotification, object: nil)
    }

    public func configureGestures() {
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(handleSidebarSwipe))
        swipe.minimumNumberOfTouches = 1
        swipe.delegate = self
        view.addGestureRecognizer(swipe)
    }

    @objc func ubiquitousKeyValueStoreDidChange(notification: NSNotification) {
        if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            for key in keys {
                if key == "co.fluder.fsnotes.pins.shared" {
                    _ = storage.restoreCloudPins()
                }
            }

            DispatchQueue.main.async {
                self.updateTable() {}
            }
        }
    }

    @objc func togglseSearch(refreshControl: UIRefreshControl) {
        self.toggleSearchView()
        refreshControl.endRefreshing()
    }

    private func toggleSearchView() {
        if self.searchView.isHidden {
            self.searchView.isHidden = false
            self.search.becomeFirstResponder()
        } else {
            self.searchView.isHidden = true
            self.search.endEditing(true)
            self.search.text = nil
            self.updateTable {}

            if shouldReturnToControllerIndex != 0 {
                guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else { return }
                bvc.containerController.selectController(atIndex: shouldReturnToControllerIndex, animated: true)

                shouldReturnToControllerIndex = 0
                UIApplication.getEVC().refill()
            }
        }
    }

    private func getEVC() -> EditorViewController? {
        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let nav = pc.containerController.viewControllers[1] as? UINavigationController,
            let evc = nav.viewControllers.first as? EditorViewController else { return nil }

        return evc
    }

    public func configureIndicator(indicator: UIActivityIndicatorView, view: UIView) {
        indicator.frame = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
        indicator.center = view.center
        indicator.layer.cornerRadius = 5
        indicator.layer.borderWidth = 1
        indicator.layer.borderColor = UIColor.lightGray.cgColor
        indicator.mixedBackgroundColor = MixedColor(normal: 0xb7b7b7, night: 0x47444e)
        view.addSubview(indicator)
        indicator.bringSubviewToFront(view)
    }

    public func startAnimation(indicator: UIActivityIndicatorView?) {
        DispatchQueue.main.async {
            indicator?.startAnimating()
            indicator?.layer.zPosition = 101
        }
    }

    public func stopAnimation(indicator: UIActivityIndicatorView?) {
        DispatchQueue.main.async {
            indicator?.stopAnimating()
            indicator?.layer.zPosition = -1
        }
    }

    public func loadNotesTable() {
        self.updateTable() {
            self.stopAnimation(indicator: self.indicator)
        }
    }

    public func loadSidebar() {
        self.sidebarTableView.dataSource = self.sidebarTableView
        self.sidebarTableView.delegate = self.sidebarTableView
        self.sidebarTableView.viewController = self
        self.maxSidebarWidth = self.calculateLabelMaxWidth()

        if UserDefaultsManagement.sidebarIsOpened {
            UIApplication.getVC().resizeSidebar()
        }
    }

    public func updateTable(search: Bool = false, sidebarItem: SidebarItem? = nil, completion: @escaping () -> Void) {
        isActiveTableUpdating = true
        searchQueue.cancelAllOperations()

        notesTable.notes.removeAll()
        notesTable.reloadData()

        startAnimation(indicator: self.indicator)

        let filter = self.search.text!
        var terms = filter.split(separator: " ")
        let sidebarItem = sidebarItem ?? self.sidebarTableView.getSidebarItem()
        let type: SidebarItemType = sidebarItem?.type ?? .Inbox

        if type == .Todo {
            terms.append("- [ ]")
        }

        self.searchQueue.cancelAllOperations()

        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self] in
            guard let self = self else {
                completion()
                return
            }

            self.accessTime = DispatchTime.now()

            let source = self.storage.noteList
            var notes = [Note]()

            for note in source {
                if operation.isCancelled {
                    break
                }

                if (
                    !note.name.isEmpty
                        && (
                            filter.isEmpty && type != .Todo || type == .Todo
                                && self.isMatched(note: note, terms: ["- [ ]"])
                                || self.isMatched(note: note, terms: terms)
                        ) && (
                            self.isFit(note: note, sidebarItem: sidebarItem, filter: filter)
                    )
                ) {
                    notes.append(note)
                }
            }

            DispatchQueue.main.async {
                self.folderCapacity.text = String(notes.count)
            }

            if !notes.isEmpty {
                if search {
                    self.notesTable.notes = notes
                } else {
                    self.notesTable.notes = self.storage.sortNotes(noteList: notes, filter: "", project: sidebarItem?.project)
                }
            } else {
                self.notesTable.notes.removeAll()
            }

            if operation.isCancelled {
                completion()
                return
            }

            //let delayInSeconds = 0.3
            DispatchQueue.main.async {
                if DispatchTime.now() < self.accessTime {
                    completion()
                    return
                }

                self.notesTable.reloadData()

                if let note = self.delayedInsert {
                    self.notesTable.insertRow(note: note)
                    self.delayedInsert = nil
                }

                self.isActiveTableUpdating = false
                self.stopAnimation(indicator: self.indicator)

                completion()
            }
        }

        self.searchQueue.addOperation(operation)
    }

    public func updateNotesCounter() {
        DispatchQueue.main.async {
            self.folderCapacity.text = String(self.notesTable.notes.count)
        }
    }

    public func isFit(note: Note, sidebarItem: SidebarItem? = nil, filter: String? = nil) -> Bool {
        var type: SidebarItemType = sidebarItem?.type ?? .Inbox

        // Global search if sidebar not checked
        if let filter = filter, filter.count > 0 && sidebarItem?.type == nil {
            type = .All
        }

        var project: Project? = nil
        var sidebarName = ""

        if let sidebarItem = sidebarItem {
            sidebarName = sidebarItem.name
            project = sidebarItem.project
        }

        if type == .Trash && note.isTrash()
            || type == .All && note.project.showInCommon
            || !UserDefaultsManagement.inlineTags && type == .Tag && note.tagNames.contains(sidebarName)
            || UserDefaultsManagement.inlineTags && type == .Tag && note.tags.contains(sidebarName)
            || [.Category, .Label].contains(type) && project != nil && note.project == project
            || project != nil && project!.isRoot && note.project.parent == project && type != .Inbox
            || type == .Archive && note.project.isArchive
            || type == .Todo && !note.project.isArchive
            || type == .Inbox && note.project.isRoot && note.project.isDefault
        {

            return true
        }

        return false
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
        updateTable(search: true) {}
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        shouldReturnToControllerIndex = 0

        guard let name = searchBar.text, name.count > 0 else {
            searchBar.endEditing(true)
            return
        }
        guard let project = self.storage.getProjects().first else { return }

        search.text = ""

        let note = Note(name: name, project: project)

        if project.firstLineAsTitle {
            note.content = NSMutableAttributedString(string: "# " + name + "\n\n")
        }

        note.save()

        self.updateTable() {}

        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
           let nav = pc.containerController.viewControllers[1] as? UINavigationController,
           let evc = nav.viewControllers.first as? EditorViewController else { return }

        evc.note = note

        pc.containerController.selectController(atIndex: 1, animated: true)
        evc.fill(note: note)

        DispatchQueue.main.async {
            evc.editArea.becomeFirstResponder()
        }
    }

    private var addButton: UIButton?

    func loadPlusButton() {
        if let button = getButton() {
            let width = self.view.frame.width
            let height = self.view.frame.height

            button.frame = CGRect(origin: CGPoint(x: CGFloat(width - 80), y: CGFloat(height - 80)), size: CGSize(width: 60, height: 60))
            return
        }

        let button = UIButton(frame: CGRect(origin: CGPoint(x: self.view.frame.width - 80, y: self.view.frame.height - 80), size: CGSize(width: 60, height: 60)))
        let image = UIImage(named: "plus.png")
        button.setImage(image, for: UIControl.State.normal)
        button.tag = 1
        button.tintColor = UIColor(red:0.49, green:0.92, blue:0.63, alpha:1.0)
        button.addTarget(self, action: #selector(self.newButtonAction), for: .touchDown)
        button.layer.zPosition = 101
        self.view.addSubview(button)
    }

    private func getButton() -> UIButton? {
        for sub in self.view.subviews {

            if sub.tag == 1 {
                return sub as? UIButton
            }
        }

        return nil
    }

    @objc func newButtonAction() {
        createNote(content: nil)
    }

    func createNote(content: String? = nil, pasteboard: Bool? = nil) {
        var currentProject: Project
        var tag: String?

        if let project = storage.getProjects().first {
            currentProject = project
        } else {
            return
        }

        if let item = self.sidebarTableView.getSidebarItem() {
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

        note.write()

        if pasteboard != nil {
            savePasteboard(note: note)
        }

        let storage = Storage.sharedInstance()
        storage.add(note)

        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
           let nav = pc.containerController.viewControllers[1] as? UINavigationController,
           let evc = nav.viewControllers.first as? EditorViewController else { return }

        pc.containerController.selectController(atIndex: 1, animated: true)

        evc.note = note
        evc.fill(note: note)

        if self.isActiveTableUpdating {
            self.delayedInsert = note
        } else {
            self.notesTable.insertRow(note: note)
        }

        if is3DTouchShortcut {
            is3DTouchShortcut = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if evc.editArea != nil {
                    evc.editArea.becomeFirstResponder()
                }
            }
        }
    }

    public func savePasteboard(note: Note) {
        let pboard = UIPasteboard.general
        let pasteboardString: String? = pboard.string

        if let content = pasteboardString {
            note.content = NSMutableAttributedString(string: content)
        }

        if let image = pboard.image {
            if let data = image.jpegData(compressionQuality: 1) {
                guard let imagePath = ImagesProcessor.writeFile(data: data, note: note) else { return }

                note.content = NSMutableAttributedString(string: "![](\(imagePath))\n\n")
            }
        }

        note.save()
        note.write()
    }

    @objc func preferredContentSizeChanged() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    @objc func rotated() {
        loadPlusButton()

        DispatchQueue.main.async {
            self.loadNotesFrame()
            self.loadSidebarState()
        }
    }

    @objc func willExitForeground() {

        // load new files from sharing extension
        for url in UserDefaultsManagement.importURLs {
            cloudDriveManager?.add(url: url)
        }

        UserDefaultsManagement.importURLs = []
    }

    @objc func didChangeScreenBrightness() {
        guard UserDefaultsManagement.nightModeType == .brightness else {
            return
        }

        let brightness = Float(UIScreen.screens[0].brightness)

        if (UserDefaultsManagement.maxNightModeBrightnessLevel < brightness && NightNight.theme == .night) {
            disableNightMode()
            return
        }

        if (UserDefaultsManagement.maxNightModeBrightnessLevel > brightness && NightNight.theme == .normal) {
            enableNightMode()
        }
    }

    public func enableNightMode() {
        print("Dark mode enabled")

        NightNight.theme = .night

        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = pc.containerController.viewControllers[0] as? ViewController,
            let nav = pc.containerController.viewControllers[1] as? UINavigationController,
            let evc = nav.viewControllers.first as? EditorViewController else { return }

        guard let pvc = UIApplication.getPVC() else { return }
        pvc.removeMPreviewView()
        MPreviewView.template = nil

        UserDefaultsManagement.codeTheme = "monokai-sublime"
        NotesTextProcessor.hl = nil
        evc.refill()

        if evc.editArea != nil {
            evc.editArea.keyboardAppearance = .dark
            evc.editArea.indicatorStyle = (NightNight.theme == .night) ? .white : .black
        }

        vc.search.keyboardAppearance = .dark

        vc.sidebarTableView.reloadData()

        vc.sidebarTableView.backgroundColor = UIColor(red:0.19, green:0.21, blue:0.21, alpha:1.0)
        vc.sidebarTableView.updateColors()
        vc.sidebarTableView.layoutSubviews()
        vc.notesTable.reloadData()

        if vc.search.isFirstResponder {
            vc.search.endEditing(true)
            vc.search.becomeFirstResponder()
        }
    }

    public func disableNightMode()
    {
        print("Dark mode disabled")

        NightNight.theme = .normal

        guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
            let vc = pc.containerController.viewControllers[0] as? ViewController,
            let nav = pc.containerController.viewControllers[1] as? UINavigationController,
            let evc = nav.viewControllers.first as? EditorViewController else { return }

        guard let pvc = UIApplication.getPVC() else { return }
        pvc.removeMPreviewView()
        MPreviewView.template = nil
        
        UserDefaultsManagement.codeTheme = "atom-one-light"
        NotesTextProcessor.hl = nil
        evc.refill()

        if evc.editArea != nil {
            evc.editArea.keyboardAppearance = .default
            evc.editArea.indicatorStyle = (NightNight.theme == .night) ? .white : .black
        }

        vc.search.keyboardAppearance = .default

        vc.sidebarTableView.reloadData()
        vc.notesTable.reloadData()

        if vc.search.isFirstResponder {
            vc.search.endEditing(true)
            vc.search.becomeFirstResponder()
        }
    }

    @objc func handleSidebarSwipe(_ swipe: UIPanGestureRecognizer) {

        // check unfinished controllers animation
        if let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController, !bvc.containerController.isMoveFinished {
            return
        }

        let notchWidth = getLeftInset()

        let translation = swipe.translation(in: notesTable)
        let halfSidebar = -(self.maxSidebarWidth / 2)

        if swipe.state == .began {
            self.sidebarTableView.isUserInteractionEnabled = true

            if UserDefaultsManagement.sidebarIsOpened {
                self.notesTable.frame.size.width = self.view.frame.width - notchWidth
                self.sidebarTableView.frame.origin.x = 0 + notchWidth
            } else
            {

                // blue/blck pre safe area
                leftPreSafeArea.mixedBackgroundColor =
                    MixedColor(
                        normal: UIColor(red: 0.27, green: 0.51, blue: 0.64, alpha: 1.00),
                        night: UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.00)
                    )

                self.sidebarTableView.frame.origin.x = halfSidebar + notchWidth
            }
            return
        }

        if swipe.state == .changed {
            guard
                UserDefaultsManagement.sidebarIsOpened && translation.x + notchWidth < 0 && (translation.x + notchWidth + maxSidebarWidth) > 0
                || !UserDefaultsManagement.sidebarIsOpened && translation.x + notchWidth > 0 && translation.x + notchWidth < maxSidebarWidth
            else { return }

            UIView.animate(withDuration: 0.1, delay: 0.0, options: .beginFromCurrentState, animations: {
                self.notesTable.frame.origin.x =
                    (translation.x + notchWidth > 0 ? -self.sidebarWidth : self.maxSidebarWidth)
                    + translation.x + notchWidth

                if translation.x + notchWidth > 0 {
                    self.sidebarTableView.frame.origin.x = halfSidebar + (translation.x + notchWidth) / 2 + notchWidth
                } else {
                    self.sidebarTableView.frame.origin.x = translation.x / 2 + notchWidth
                }
            })
            return
        }

        if swipe.state == .ended {
            if translation.x > 0 {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .init(), animations: {
                    self.notesTable.frame.origin.x = self.maxSidebarWidth
                    self.notesTable.frame.size.width = self.view.frame.width - notchWidth - self.maxSidebarWidth
                    self.sidebarTableView.frame.origin.x = 0 + notchWidth
                }) { _ in
                    UserDefaultsManagement.sidebarIsOpened = true
                    self.sidebarTableView.isUserInteractionEnabled = true
                }
            }

            if translation.x < 0 {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .init(), animations: {
                    self.notesTable.frame.origin.x = 0 + notchWidth
                    self.notesTable.frame.size.width = self.view.frame.width - notchWidth
                    self.sidebarTableView.frame.origin.x = halfSidebar + notchWidth
                }) { _ in
                    UserDefaultsManagement.sidebarIsOpened = false
                    self.sidebarTableView.isUserInteractionEnabled = false

                    // white pre safe area
                    self.leftPreSafeArea.mixedBackgroundColor =
                        MixedColor(
                            normal: .white,
                            night: UIColor(red: 0.18, green: 0.17, blue: 0.20, alpha: 1.00)
                    )
                }
            }
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            self.view.frame.size.height = UIScreen.main.bounds.height
            self.view.frame.size.height -= keyboardSize.height
            loadPlusButton()
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        self.view.frame.size.height = UIScreen.main.bounds.height
        loadPlusButton()
    }

    public func refreshTextStorage(note: Note) {
        DispatchQueue.main.async {
            guard let pc = UIApplication.shared.windows[0].rootViewController as? BasicViewController,
                let nav = pc.containerController.viewControllers[1] as? UINavigationController,
                let evc = nav.viewControllers.first as? EditorViewController else { return }

            evc.fill(note: note)
        }
    }

    private func calculateLabelMaxWidth() -> CGFloat {
        var width = CGFloat(115)
        let font = UIFont.boldSystemFont(ofSize: 15.0)

        let settings = NSLocalizedString("Settings", comment: "Sidebar settings")
        let inbox = NSLocalizedString("Inbox", comment: "Inbox in sidebar")
        let notes = NSLocalizedString("Notes", comment: "Notes in sidebar")
        let todo = NSLocalizedString("Todo", comment: "Todo in sidebar")
        let archive = NSLocalizedString("Archive", comment: "Archive in sidebar")
        let trash = NSLocalizedString("Trash", comment: "Trash in sidebar")

        var sidebarItems = [String]()
        if let projects = sidebarTableView.getSelectedProjects() {
            sidebarItems = sidebarTableView.getAllTags(projects: projects)
        }

        sidebarItems = sidebarItems
            + Storage.sharedInstance().getProjects().map({ $0.label })
            + [settings, inbox, notes, todo, archive, trash]

        for item in sidebarItems {
            let labelWidth = ("#                " + item as NSString).size(withAttributes: [.font: font]).width

            if labelWidth < view.frame.size.width / 2 {
                if labelWidth > width {
                    width = labelWidth
                }
            } else {
                width = view.frame.size.width / 2
            }
        }

        return width
    }

    public func unLock(notes: [Note], completion: @escaping ([Note]?) -> ()) {
        getMasterPassword() { password in
            for note in notes {
                var success: [Note]? = nil
                if note.unLock(password: password) {
                    success?.append(note)
                }

                DispatchQueue.main.async {
                    self.notesTable.reloadRowForce(note: note)
                }

                completion(success)
            }
        }
    }

    public func toggleNotesLock(notes: [Note]) {
        var notes = notes
        guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else { return }

        notes = lockUnlocked(notes: notes)
        guard notes.count > 0 else { return }

        getMasterPassword() { password in
            for note in notes {
                if note.container == .encryptedTextPack {
                    if note.unLock(password: password) {
                        DispatchQueue.main.async {
                            self.notesTable.reloadRowForce(note: note)
                            UIApplication.getEVC().fill(note: note)
                            bvc.containerController.selectController(atIndex: 1, animated: true)
                        }
                    }
                } else {
                    if note.encrypt(password: password) {
                        DispatchQueue.main.async {
                            self.notesTable.reloadRowForce(note: note)
                        }
                    }
                }
            }
        }
    }

    private func lockUnlocked(notes: [Note]) -> [Note] {
        var notes = notes
        var isFirst = true

        for note in notes {
            if note.isUnlocked() {
                if note.lock() && isFirst {
                    notesTable.reloadRowForce(note: note)
                }
                notes.removeAll { $0 === note }
            }
            isFirst = false
        }

        return notes
    }

    public func getMasterPassword(completion: @escaping (String) -> ()) {
        let context = LAContext()
        context.localizedFallbackTitle = NSLocalizedString("Enter Master Password", comment: "")

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            masterPasswordPrompt(completion: completion)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "To access master password") { (success, evaluateError) in

            if !success {
                self.masterPasswordPrompt(completion: completion)
                return
            }

            do {
                let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")
                let password = try item.readPassword()

                completion(password)
                return
            } catch {
                print(error)
            }

            self.masterPasswordPrompt(completion: completion)
        }
    }

    private func masterPasswordPrompt(completion: @escaping (String) -> ()) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Master password:", message: nil, preferredStyle: .alert)

            alertController.addTextField(configurationHandler: {
                [] (textField: UITextField) in
                textField.placeholder = "mast3r passw0rd"
            })

            let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
                guard let password = alertController.textFields?[0].text, password.count > 0 else {
                    return
                }

                let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")
                do {
                    try item.savePassword(password)
                } catch {}

                completion(password)
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }

            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)

            self.present(alertController, animated: true) {
                alertController.textFields![0].selectAll(nil)
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        guard UserDefaultsManagement.nightModeType == .system else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkDarkMode()
        }
    }

    public func checkDarkMode() {
        if #available(iOS 12.0, *) {
            if traitCollection.userInterfaceStyle == .dark {
                if NightNight.theme != .night {
                    enableNightMode()
                }
            } else {
                if NightNight.theme == .night {
                    disableNightMode()
                }
            }
        }
    }

    public func resizeSidebar() {
        let width = calculateLabelMaxWidth()
        maxSidebarWidth = width

        let notchWidth = getLeftInset()

        if UserDefaultsManagement.sidebarIsOpened {
            if maxSidebarWidth > view.frame.size.width {
                maxSidebarWidth = view.frame.size.width / 2
            }

            UIView.animate(withDuration: 0.2, delay: 0.0, options: .init(), animations: {
                self.notesTable.frame.origin.x = self.maxSidebarWidth
                self.notesTable.frame.size.width = self.view.frame.width - notchWidth - self.maxSidebarWidth
                self.sidebarTableView.frame.origin.x = 0 + notchWidth
            })
        }
    }
}

extension ViewController : UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

extension UIApplication {
    public func runInBackground(_ closure: @escaping () -> Void, expirationHandler: (() -> Void)? = nil) {
        let taskID: UIBackgroundTaskIdentifier
        if let expirationHandler = expirationHandler {
            taskID = self.beginBackgroundTask(expirationHandler: expirationHandler)
        } else {
            taskID = self.beginBackgroundTask(expirationHandler: { })
        }

        DispatchQueue.global(qos: .background).sync {
            closure()
        }
        self.endBackgroundTask(taskID)
    }
}
