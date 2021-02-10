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
import WebKit
import AudioToolbox
import CoreSpotlight

class ViewController: UIViewController, UISearchBarDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var preHeaderView: UIView!
    @IBOutlet weak var currentFolder: UILabel!
    @IBOutlet weak var folderCapacity: UILabel!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var search: UISearchBar!
    @IBOutlet weak var bulkButton: UIButton!
    @IBOutlet weak var searchCancel: UIButton!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var searchView: UIView!
    @IBOutlet weak var notesTable: NotesTableView!
    @IBOutlet weak var sidebarTableView: SidebarTableView!

    @IBOutlet weak var leftPreSafeArea: UIView!
    @IBOutlet weak var rightPreSafeArea: UIView!

    @IBOutlet weak var leftPreHeader: UIView!
    @IBOutlet weak var rightPreHeader: UIView!

    private var newsPopup: MPreviewView?
    private var newsOverlay: UIView?

    public var indicator: UIActivityIndicatorView?

    public var storage = Storage.shared()
    public var cloudDriveManager: CloudDriveManager?

    private let searchQueue = OperationQueue()
    private let metadataQueue = OperationQueue()
    private var delayedInsert: Note?

    private var maxSidebarWidth = CGFloat(0)
    private var accessTime = DispatchTime.now()

    public var isActiveTableUpdating = false

    private var queryDidFinishGatheringObserver : Any?
    private var isBackground: Bool = false

    public var shouldReturnToControllerIndex: Int = 0

    // Swipe animation from handleSidebarSwipe
    private var sidebarWidth: CGFloat = 0
    private var isLandscape: Bool?

    // Last selected project abd tag in sidebar
    public var searchQuery: SearchQuery = SearchQuery(type: .Inbox)
    public var restoreActivity: URL?

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

        bulkButton.imageView?.image = UIImage(named: "navigationBulk")?.imageWithColor(color1: .white)

        super.viewDidAppear(animated)
    }

    override func viewDidLoad() {
        loadInbox()

        startCloudDriveSyncEngine()

        configureUI()
        configureNotifications()
        configureGestures()

        loadNotesTable()
        loadSidebar()

        loadNotches()
        loadPreSafeArea()

        preLoadProjectsData()
        loadNews()

        super.viewDidLoad()
    }

    public func loadInbox() {
        guard let project = storage.getDefault() else { return }

        project.loadNotes()
    }

    public func startCloudDriveSyncEngine(completion: (() -> ())? = nil) {
        cloudDriveManager = CloudDriveManager(delegate: self, storage: self.storage)
        cloudDriveManager?.metadataQuery.disableUpdates()

        if let cdm = self.cloudDriveManager {
            self.queryDidFinishGatheringObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: cdm.metadataQuery, queue: self.metadataQueue) { notification in

                cdm.queryDidFinishGathering(notification: (notification as NSNotification))

                completion?()

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

    public func configureUI() {
        UINavigationBar.appearance().isTranslucent = false

        if UserDefaultsManagement.isFirstLaunch {
            UserDefaultsManagement.fontName = "Avenir Next"
            UserDefaultsManagement.isFirstLaunch = false
        }

        loadNotesFrame()

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

        bulkButton.imageView?.image = UIImage(named: "navigationBulk")?.imageWithColor(color1: .white)
        self.searchButton.setImage(UIImage(named: "search_white"), for: .normal)

        let settingsIcon = UIImage(named: "more_row_action")!.resize(maxWidthHeight: 34)?.imageWithColor(color1: .white)
        self.settingsButton.setImage(settingsIcon, for: .normal)

        self.headerView.mixedBackgroundColor = Colors.Header

        self.headerView.addBottomBorderWithColor(color: UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.00), width: 1)
        self.searchView.mixedBackgroundColor = Colors.Header

        self.search.mixedBackgroundColor = Colors.Header
        self.search.mixedBarTintColor = Colors.Header
        self.search.returnKeyType = .go
         if let textFieldInsideSearchBar = self.search.value(forKey: "searchField") as? UITextField,
               let glassIconView = textFieldInsideSearchBar.leftView as? UIImageView {
                   glassIconView.image = glassIconView.image?.withRenderingMode(.alwaysTemplate)
                   glassIconView.tintColor = .white
           }

        self.currentFolder.text = NSLocalizedString("Inbox", comment: "")
        self.searchCancel.titleLabel?.text = NSLocalizedString("Cancel", comment: "")
        self.search.placeholder = NSLocalizedString("Search or create", comment: "")
        self.folderCapacity.mixedTextColor = Colors.titleText
        self.currentFolder.mixedTextColor = Colors.titleText
        self.currentFolder.isUserInteractionEnabled = true
        self.currentFolder.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.openSidebarSettings)))

        self.searchCancel.mixedTintColor = Colors.buttonText
        search.keyboardAppearance = NightNight.theme == .night ? .dark : .default

        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)
        notesTable.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

        let searchBarTextField = search.value(forKey: "searchField") as? UITextField
        searchBarTextField?.mixedTextColor = MixedColor(normal: 0xfafafa, night: 0xfafafa)

        loadPlusButton()

        search.delegate = self
        search.autocapitalizationType = .none

        notesTable.viewDelegate = self

        notesTable.dragInteractionEnabled = true
        notesTable.dragDelegate = notesTable
        sidebarTableView.dropDelegate = sidebarTableView

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

        let longTapOnSidebar = UILongPressGestureRecognizer(target: self, action: #selector(sidebarLongPress))
        longTapOnSidebar.minimumPressDuration = 0.5
        view.addGestureRecognizer(longTapOnSidebar)
    }

    @IBAction public func sidebarLongPress(gesture: UILongPressGestureRecognizer) {
        guard UserDefaultsManagement.sidebarIsOpened else { return }

        let p = gesture.location(in: self.sidebarTableView)

        guard p.x < maxSidebarWidth, let indexPath = self.sidebarTableView.indexPathForRow(at: p) else { return }

        if gesture.state != .ended {
            sidebarTableView.tableView(sidebarTableView, didSelectRowAt: indexPath)

            openSidebarSettings()
        }

        gesture.state = .ended
    }

    public func loadNotesTable() {
        reloadNotesTable(with: SearchQuery(type: .Inbox)) {
            self.stopAnimation(indicator: self.indicator)
        }
    }

    public func loadSidebar() {
        sidebarTableView.dataSource = self.sidebarTableView
        sidebarTableView.delegate = self.sidebarTableView
        sidebarTableView.viewController = self
        maxSidebarWidth = self.calculateLabelMaxWidth()

        if UserDefaultsManagement.sidebarIsOpened {
            resizeSidebar()
        }

        guard Storage.shared().getRoot() != nil else { return }

        DispatchQueue.main.async {
            let inboxIndex = IndexPath(row: 0, section: 0)
            self.sidebarTableView.tableView(self.sidebarTableView, didSelectRowAt: inboxIndex)
        }
    }

    public func preLoadProjectsData() {
        guard Storage.shared().getRoot() != nil else { return }

        DispatchQueue.global(qos: .userInteractive).async {
            let storage = self.storage

            let projectsLoading = Date()
            self.checkProjectsCacheDiff()
            print("0. Projects diff loading finished in \(projectsLoading.timeIntervalSinceNow * -1) seconds")

            let cacheLoading = Date()
            let projects = storage.findAllProjectsExceptDefault()

            for project in projects {
                project.loadNotes()
            }

            print("1. Cache loading finished in \(cacheLoading.timeIntervalSinceNow * -1) seconds")

            let diffLoading = Date()
            for project in storage.getProjects() {
                self.checkNotesCacheDiff(for: project)
            }

            print("2. Notes diff loading finished in \(diffLoading.timeIntervalSinceNow * -1) seconds")

            // enable iCloud Drive updates after projects structure formalized
            self.cloudDriveManager?.metadataQuery.enableUpdates()

            let tagsPoint = Date()
            storage.loadAllTags()
            print("3. Tags loading finished in \(tagsPoint.timeIntervalSinceNow * -1) seconds")

            DispatchQueue.main.async {
                self.importSavedInSharedExtension()
                self.sidebarTableView.loadAllTags()
            }

            // fill note from spotlight action
            if let restore = self.restoreActivity {
                if let note = Storage.shared().getBy(url: restore) {
                    DispatchQueue.main.async {
                        UIApplication.getEVC().load(note: note)
                    }
                }
            }

            let spotlightPoint = Date()
            self.reIndexSpotlight()
            print("4. Spotlight indexation finished in \(spotlightPoint.timeIntervalSinceNow * -1) seconds")
        }
    }

    private func reIndexSpotlight() {
        CSSearchableIndex.default().deleteAllSearchableItems { (error) in
            if let error = error {
                print("Spotlight \(error)")
            }
        }

        var spotlightItems = [CSSearchableItem]()
        for note in storage.noteList {
            if note.project.isTrash || !note.project.showInCommon {
                continue
            }

            let attributed = CSSearchableItemAttributeSet(itemContentType: "Text")
            attributed.title = note.title
            attributed.contentDescription = note.content.string
            attributed.lastUsedDate = note.modifiedLocalAt

            let item = CSSearchableItem(uniqueIdentifier: note.url.path, domainIdentifier: "Notes", attributeSet: attributed)
            spotlightItems.append(item)
        }

        CSSearchableIndex.default().indexSearchableItems(spotlightItems) { (error) in
            if let error = error {
                print("Spotlight \(error)")
            }
        }
    }

    public func updateSpotlightIndex(notes: [Note]) {
        var items = [CSSearchableItem]()
        for note in notes {
            let attributed = CSSearchableItemAttributeSet(itemContentType: "Text")
            attributed.title = note.title
            attributed.contentDescription = note.content.string
            attributed.lastUsedDate = note.modifiedLocalAt

            let item = CSSearchableItem(uniqueIdentifier: note.url.path, domainIdentifier: "Notes", attributeSet: attributed)
            items.append(item)
        }

        CSSearchableIndex.default().indexSearchableItems(items, completionHandler: nil)
    }

    public func removeSpotlightIndex(notes: [Note]) {
        var idents = [String]()
        for note in notes {
            idents.append(note.url.path)
        }

        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: idents, completionHandler: nil)
    }

    private func loadNews() {
        guard storage.isReadedNewsOutdated() else { return }

        let isLandscape = UIDevice.current.orientation.isLandscape
        newsPopup?.removeFromSuperview()
        newsOverlay?.removeFromSuperview()

        let screeenWidth = UIScreen.main.bounds.width
        let screeenHeight = UIScreen.main.bounds.height

        let overlay = UIView(frame: CGRect(x: 0, y: 0, width: screeenWidth, height: screeenHeight))
        overlay.layer.zPosition = 104
        overlay.backgroundColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.5)
        view.addSubview(overlay)
        self.newsOverlay = overlay

        var width = UIScreen.main.bounds.width - 20
        if isLandscape {
            width = UIScreen.main.bounds.width * 0.75
        }

        let height = screeenHeight * 0.75
        let note = Note(
            url: storage.getNews()!,
            with: storage.getDefault()!
        )
        note.load()

        let frame = CGRect(
            x: (screeenWidth - width) / 2,
            y: (screeenHeight - height) / 2,
            width: width,
            height: height
        )

        let news = MPreviewView(frame: frame, note: note, closure: {})
        news.layer.zPosition = 105
        news.backgroundColor = UIColor.white
        news.layer.cornerRadius = 5
        news.layer.masksToBounds = true
        news.layer.borderWidth = 1
        news.layer.borderColor = UIColor.gray.cgColor

        let closeButton = UIButton(frame: CGRect(origin: CGPoint(x: width - 10 - 25, y: 10), size: CGSize(width: 25, height: 25)))
        let image = UIImage(named: "close-window.png")
        closeButton.setImage(image, for: UIControl.State.normal)
        closeButton.tintColor = UIColor(red:0.49, green:0.92, blue:0.63, alpha:1.0)
        closeButton.addTarget(self, action: #selector(closeNews), for: .touchDown)
        closeButton.layer.zPosition = 110
        news.addSubview(closeButton)
        view.addSubview(news)

        self.newsPopup = news

    }

    public func saveProjectURLs() {
        UserDefaultsManagement.projects =
            storage.getProjects()
                .filter({ !$0.isTrash && !$0.isArchive && !$0.isDefault })
                .compactMap({ $0.url })
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

    public func loadNotesFrame(keyboardHeight: CGFloat? = nil) {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        let top = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
        let right = UIApplication.shared.windows.first?.safeAreaInsets.right ?? 0
        let left = UIApplication.shared.windows.first?.safeAreaInsets.left ?? 0
        let navHeight: CGFloat = 45

        let topInset = top + navHeight
        let leftInset = left
        let keyboardHeight = keyboardHeight ?? 0

        notesTable.translatesAutoresizingMaskIntoConstraints = true
        sidebarTableView.translatesAutoresizingMaskIntoConstraints = true

        notesTable.frame.origin.x = leftInset
        notesTable.frame.origin.y = topInset
        notesTable.frame.size.width = screenWidth - left - right - navHeight
        notesTable.frame.size.height = screenHeight - topInset - keyboardHeight

        sidebarTableView.frame.origin.x = leftInset
        sidebarTableView.frame.origin.y = topInset
        sidebarTableView.frame.size.width = screenWidth - left - right
        sidebarTableView.frame.size.height = screenHeight - topInset - keyboardHeight

        loadPreSafeArea()
        loadSidebarState()
    }

    public func loadNotches() {
        rightPreSafeArea.mixedBackgroundColor =
            MixedColor(
                normal: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.00),
                night: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            )

        preHeaderView.mixedBackgroundColor =
            MixedColor(
                normal: UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00),
                night: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            )

        leftPreHeader.mixedBackgroundColor =
            MixedColor(
                normal: UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00),
                night: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            )

        rightPreHeader.mixedBackgroundColor =
            MixedColor(
                normal: UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00),
                night: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            )
    }

    public func loadPreSafeArea() {
        if UserDefaultsManagement.sidebarIsOpened {
            // blue/black pre safe area
            leftPreSafeArea.mixedBackgroundColor =
                MixedColor(
                    normal: UIColor(red: 0.27, green: 0.51, blue: 0.64, alpha: 1.00),
                    night: UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.00)
                )

            rightPreSafeArea.mixedBackgroundColor =
                MixedColor(
                    normal: .white,
                    night: .black
                )

            notesTable.frame.size.width = self.view.frame.width - self.getLeftInset() - maxSidebarWidth
        } else {
            leftPreSafeArea.mixedBackgroundColor =
                MixedColor(
                    normal: .white,
                    night: .black
                )

            rightPreSafeArea.mixedBackgroundColor =
                MixedColor(
                    normal: .white,
                    night: .black
                )

            notesTable.frame.size.width = self.view.frame.width - self.getLeftInset()
        }
    }


    @IBAction func openSearchView(_ sender: Any) {
        self.toggleSearchView()
    }

    @IBAction func hideSearchView(_ sender: Any) {
        self.toggleSearchView()
    }

    @IBAction func bulkEditing(_ sender: Any) {
        if notesTable.isEditing {
            let navImage = UIImage(named: "navigationBulk")?.imageWithColor(color1: .white)
            self.bulkButton.setImage(navImage, for: .normal)

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
            self.bulkButton.setImage(UIImage(named: "done_white.png"), for: .normal)
        }
    }

    @objc public func openSettings() {
        let sourceSelectorTableViewController = SettingsViewController()
        let navigationController = UINavigationController(rootViewController: sourceSelectorTableViewController)

        navigationController.modalPresentationStyle = .fullScreen

        self.present(navigationController, animated: true, completion: nil)
    }

    @objc func ubiquitousKeyValueStoreDidChange(notification: NSNotification) {
        if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            for key in keys {
                if key == "co.fluder.fsnotes.pins.shared" {
                    let result = storage.restoreCloudPins()

                    DispatchQueue.main.async {
                        if let added = result.added {
                            self.notesTable.addPins(notes: added)
                        }

                        if let removed = result.removed {
                            self.notesTable.removePins(notes: removed)
                        }
                    }
                }
            }
        }
    }

    @objc func togglseSearch(refreshControl: UIRefreshControl) {
        self.toggleSearchView()
        refreshControl.endRefreshing()
    }

    private func toggleSearchView() {
        if self.searchView.isHidden {
            searchView.isHidden = false
            search.becomeFirstResponder()
            sidebarTableView.deselectAll()
            reloadNotesTable(with: SearchQuery())
        } else {
            turnOffSearch()
            sidebarTableView.restoreSelection(for: searchQuery)
            reloadNotesTable(with: searchQuery)

            if shouldReturnToControllerIndex != 0 {
                guard let bvc = UIApplication.shared.windows[0].rootViewController as? BasicViewController else { return }
                bvc.containerController.selectController(atIndex: shouldReturnToControllerIndex, animated: true)

                shouldReturnToControllerIndex = 0
                UIApplication.getEVC().refill()
            }
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard searchText.count > 0 else {
            reloadNotesTable(with: SearchQuery())
            return
        }

        reloadNotesTable(with: SearchQuery(filter: searchText))
    }

    public func turnOffSearch() {
        searchView.isHidden = true
        search.endEditing(true)
        search.text = nil
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

    public func saveLastValid(searchQuery: SearchQuery) {
        if searchQuery.project == nil
            && searchQuery.tag == nil
            && searchQuery.type == nil {
            return
        }
        
        self.searchQuery = searchQuery
    }

    public func reloadNotesTable(with query: SearchQuery? = nil, completion: (() -> ())? = nil) {

        let query = query ?? searchQuery

        // remember query params
        if query.terms == nil || query.type == .Todo {
            saveLastValid(searchQuery: query)
        }

        isActiveTableUpdating = true
        searchQueue.cancelAllOperations()
        folderCapacity.text = String("∞")
        searchQueue.cancelAllOperations()

        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self] in
            guard let self = self else {
                completion?()
                return
            }

            self.accessTime = DispatchTime.now()

            let source = self.storage.noteList
            var notes = [Note]()

            for note in source {
                if operation.isCancelled {
                    break
                }

                if self.isFit(note: note, searchQuery: query) {
                    notes.append(note)
                }
            }

            if notes.isEmpty {
                self.notesTable.notes.removeAll()
            } else {
                self.notesTable.notes =
                    self.storage.sortNotes(
                        noteList: notes,
                        filter: query.getFilter(),
                        project: query.project
                    )
            }

            if operation.isCancelled {
                completion?()
                return
            }

            DispatchQueue.main.async {
                self.folderCapacity.text = String(notes.count)

                if DispatchTime.now() < self.accessTime {
                    completion?()
                    return
                }

                self.notesTable.reloadData()

                if let note = self.delayedInsert {
                    self.notesTable.insertRows(notes: [note])
                    self.delayedInsert = nil
                }

                self.isActiveTableUpdating = false
                self.stopAnimation(indicator: self.indicator)

                completion?()
            }
        }

        self.searchQueue.addOperation(operation)
    }

    public func updateNotesCounter() {
        DispatchQueue.main.async {
            self.folderCapacity.text = String(self.notesTable.notes.count)
        }
    }

    public func isNoteInsertionAllowed() -> Bool {
        return !search.isFirstResponder
    }

    public func isFitInCurrentSearchQuery(note: Note) -> Bool {
        return isFit(note: note, searchQuery: searchQuery)
    }

    public func isFit(note: Note, searchQuery: SearchQuery) -> Bool {
        guard !note.name.isEmpty
            && (
                searchQuery.terms == nil
                    || self.isMatched(note: note, terms: searchQuery.terms!)
            )
        else { return false }

        if searchQuery.tag != nil {
            if searchQuery.project != nil
                && note.tags.contains(searchQuery.tag!)
                && note.project == searchQuery.project {
                return true
            }

            if (
                searchQuery.type == .All
                    || searchQuery.type == .Todo
                    || searchQuery.type == .Tag
            ) && note.tags.contains(searchQuery.tag!) {
                return true
            }

            return false
        }

        guard
            searchQuery.type == .Trash
                && note.isTrash()
            || searchQuery.terms != nil
                && note.project.showInCommon
            || searchQuery.type == .All
                && note.project.showInCommon
            || searchQuery.type == .Category
                && searchQuery.project != nil
                && note.project == searchQuery.project
            || searchQuery.project != nil && searchQuery.project!.isRoot
                && note.project.parent == searchQuery.project
                && searchQuery.type != .Inbox
            || searchQuery.type == .Archive
                && note.project.isArchive
            || searchQuery.type == .Todo
                && !note.project.isArchive
                && note.project.showInCommon
            || searchQuery.type == .Inbox
                && note.project.isRoot
                && note.project.isDefault
        else {
            return false
        }

        return true
    }

    private func isMatched(note: Note, terms: [Substring]) -> Bool {
        for term in terms {
            if note.name.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: nil) != nil ||
                note.content.string.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: nil) != nil {
                continue
            }

            return false
        }

        return true
    }

    public func loadSettingsButton() {
        let height = view.frame.height
        let button = UIButton(frame: CGRect(origin: CGPoint(x: 0, y: height - 150), size: CGSize(width: 200, height: 60)))
        let image = UIImage(named: "settings.png")
        button.setImage(image, for: UIControl.State.normal)
        button.setTitle(NSLocalizedString("Settings", comment: "Sidebar settings"), for: .normal)
        button.tag = 1
        button.tintColor = UIColor(red:0.49, green:0.92, blue:0.63, alpha:1.0)
        button.addTarget(self, action: #selector(self.openSettings), for: .touchDown)
        button.layer.zPosition = 101

        //sidebarTableView.contentOffset = .init(x: 0, y: -100)
        sidebarTableView.contentInset = .init(top: 0, left: 0, bottom: 100, right: 0)
        settingsButton = button
        
        self.view.addSubview(settingsButton)

    }

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

    @objc public func closeNews() {
        newsPopup?.removeFromSuperview()
        newsOverlay?.removeFromSuperview()

        // mark as read
        UserDefaultsManagement.lastNews = storage.getNewsDate()
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

            if let project = item.project,
                !project.isTrash,
                !project.isVirtual {
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
            notesTable.insertRows(notes: [note])
            notesTable.scrollTo(note: note)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            evc.editArea.becomeFirstResponder()
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

    public func importSavedInSharedExtension() {
        for url in UserDefaultsManagement.importURLs {
            guard let note = storage.importNote(url: url) else { return }

            if !storage.contains(note: note) {
                storage.noteList.append(note)
                notesTable.insertRows(notes: [note])

                print("File imported: \(note.url)")
            }
        }

        UserDefaultsManagement.importURLs = []
    }

    @objc func preferredContentSizeChanged() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    @objc func rotated() {
        guard isLandscape != nil else {
            isLandscape = UIDevice.current.orientation.isLandscape
            return
        }

        let isLand = UIDevice.current.orientation.isLandscape
        if let landscape = self.isLandscape, landscape != isLand, !UIDevice.current.orientation.isFlat {
            isLandscape = isLand

            loadPlusButton()
            loadNews()

            DispatchQueue.main.async {
                self.loadNotesFrame()
                self.loadSidebarState()
            }
        }
    }

    @objc func willExitForeground() {
        importSavedInSharedExtension()
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
        vc.sidebarTableView.backgroundColor = UIColor(red:0.19, green:0.21, blue:0.21, alpha:1.0)
        vc.sidebarTableView.updateColors()

        vc.sidebarTableView.layoutSubviews()
        vc.notesTable.layoutSubviews()
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

        vc.sidebarTableView.layoutSubviews()
        vc.notesTable.layoutSubviews()
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
                            night: .black
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
            loadNotesFrame(keyboardHeight: keyboardSize.height)
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        self.view.frame.size.height = UIScreen.main.bounds.height
        loadPlusButton()
        loadNotesFrame()
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
        if let project = searchQuery.project {
            sidebarItems = sidebarTableView.getAllTags(projects: [project])
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

    public func resizeSidebar(withAnimation: Bool = false) {
        let currentSidebarWidth = self.notesTable.frame.origin.x
        let width = calculateLabelMaxWidth()
        maxSidebarWidth = width

        if maxSidebarWidth < currentSidebarWidth {
            return
        }
        
        guard UserDefaultsManagement.sidebarIsOpened else { return }

        if maxSidebarWidth > view.frame.size.width {
            maxSidebarWidth = view.frame.size.width / 2
        }

        let notchWidth = getLeftInset()

        if (withAnimation) {
            UIView.animate(withDuration: 0.3, delay: 0, options: .beginFromCurrentState, animations: {

                self.notesTable.frame.origin.x = self.maxSidebarWidth
                self.notesTable.frame.size.width = self.view.frame.width - notchWidth - self.maxSidebarWidth
                self.sidebarTableView.frame.origin.x = 0 + notchWidth

            }) { _ in

            }
        } else {
            notesTable.frame.origin.x = maxSidebarWidth
            notesTable.frame.size.width = view.frame.width - notchWidth - maxSidebarWidth
            sidebarTableView.frame.origin.x = 0 + notchWidth
        }

    }

    public func checkProjectsCacheDiff() {
        let results = storage.checkFSAndMemoryDiff()

        // Save projects cache
        UserDefaultsManagement.projects =
            self.storage.getNonSystemProjects().compactMap({ $0.url })

        DispatchQueue.main.async {
            self.sidebarTableView.removeRows(projects: results.0)
            self.sidebarTableView.insertRows(projects: results.1)
        }
    }

    public func checkNotesCacheDiff(for project: Project) {
        let storage = Storage.shared()

        // if not cached – load all results for cache
        // (not loaded instantly because is resource consumption operation, loaded later in background)
        guard project.cacheUsedDiffValidationNeeded else {

            _ = storage.noteList
                .filter({ $0.project == project })
                .map({ $0.load() })

            project.isReadyForCacheSaving = true
            return
        }


        let results = project.checkFSAndMemoryDiff()

        print("Cache diff found: removed - \(results.0.count), added - \(results.1.count), modified - \(results.2.count).")

        DispatchQueue.main.async {
            self.notesTable.removeRows(notes: results.0)
            self.notesTable.insertRows(notes: results.1)
            self.notesTable.reloadRows(notes: results.2)
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

class SearchQuery {
    var type: SidebarItemType? = nil
    var project: Project? = nil
    var tag: String? = nil
    var terms: [Substring]? = nil

    init() {}

    init(type: SidebarItemType) {
        if type == .Todo {
            terms = ["- [ ] "]
        }

        self.type = type
    }

    init(filter: String) {
        terms = filter.split(separator: " ")
    }

    init(type: SidebarItemType, project: Project?, tag: String?) {
        if type == .Todo {
            terms = ["- [ ] "]
        }

        self.type = type
        self.project = project
        self.tag = tag
    }

    public func setType(_ type: SidebarItemType) {
        if type == .Todo {
            terms = ["- [ ] "]
        }

        self.type = type
    }

    public func getFilter() -> String? {
        return terms?.joined(separator: " ")
    }
}
