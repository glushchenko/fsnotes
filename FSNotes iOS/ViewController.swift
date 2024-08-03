//
//  ViewController.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 1/29/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import LocalAuthentication
import WebKit
import AudioToolbox
import CoreSpotlight

class ViewController: UIViewController, UISearchBarDelegate, UIGestureRecognizerDelegate, UISearchControllerDelegate {

    @IBOutlet weak var sidebarTableBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var notesTableBottomContraint: NSLayoutConstraint!
    @IBOutlet weak var notesTableLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var sidebarTableLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var sidebarTableWidth: NSLayoutConstraint!
    @IBOutlet weak var notesTable: NotesTableView!
    @IBOutlet weak var sidebarTableView: SidebarTableView!
    @IBOutlet weak var leftPreSafeArea: UIView!
    @IBOutlet weak var rightPreSafeArea: UIView!

    @IBOutlet weak var lockedProject: UIImageView!

    private var newsPopup: MPreviewView?
    private var newsOverlay: UIView?

    public var indicator: UIActivityIndicatorView?

    public var storage = Storage.shared()
    public var cloudDriveManager: CloudDriveManager?

    private let searchQueue = OperationQueue()
    private let metadataQueue = OperationQueue()
    
    public let gitQueue = OperationQueue()
    public let gitQueueState = OperationQueue()

    private var delayedInsert: Note?

    private var maxSidebarWidth = CGFloat(0)
    private var accessTime = DispatchTime.now()

    public var isActiveTableUpdating = false

    private var queryDidFinishGatheringObserver : Any?
    private var isBackground: Bool = false

    public var shouldReturnToControllerIndex = false

    // Swipe animation from handleSidebarSwipe
    private var sidebarWidth: CGFloat = 0
    private var isLandscape: Bool?

    public var restoreActivity: URL?
    public var restoreFindID: String?
    public var isLoadedDB: Bool = false

    public var folderCapacity: String?
    public var currentFolder: String?

    lazy var searchBar = UISearchBar(frame: CGRect.zero)
    private var searchController: UISearchController?
    
    // Pass for access from CloudDriveManager
    public var editorViewController: EditorViewController?
    
    private var gitClean: Bool = false
    private var gitPullTimer: Timer?

    private var searchFocus: Bool = false

    // Project for import picker
    public var selectedProject: Project?
    private var initialLoadingState = false

    override func viewWillAppear(_ animated: Bool) {
        configureSearchController()

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setToolbarHidden(true, animated: false)
        view.backgroundColor = .whiteBlack

        // configure proper title margin
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 10
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.largeTitleTextAttributes = [NSAttributedString.Key.paragraphStyle : style]
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        super.viewWillAppear(animated)

        reloadNotesTable() { [weak self] in
            guard let self = self else { return }
            self.stopAnimation(indicator: self.indicator)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        if nil == Storage.shared().getRoot() {
            let alert = UIAlertController(title: "Storage not found", message: "Please enable iCloud Drive for this app and try again!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .destructive, handler: { action in
                exit(0)
            }))
            self.present(alert, animated: true, completion: nil)
        }

        // Clean preview after previous loading
        UIApplication.getEVC().getPreviewView()?.clean()

        // If return from editor
        UIApplication.getEVC().userActivity?.invalidate()

        loadPreSafeArea()
        loadPlusButton()

        if let sidebarItem = UIApplication.getVC().lastSidebarItem {
            configureNavMenu(for: sidebarItem)
        }

        if searchFocus {
            disableSearchFocus()

            DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                self.navigationItem.searchController?.searchBar.becomeFirstResponder()
            })
        }

        super.viewDidAppear(animated)
    }

    override func viewDidLoad() {
        startCloudDriveSyncEngine()

        configureUI()
        configureNotifications()
        configureGestures()
        configureSearchController()
        
        gitQueue.qualityOfService = .userInteractive
        gitQueue.maxConcurrentOperationCount = 1

        gitQueueState.qualityOfService = .background
        gitQueueState.maxConcurrentOperationCount = 1

        scheduledGitPull()

        disableLockedProject()
        loadNotesTable()
        notesTable.showLoader()

        loadSidebar()

        loadNotches()
        loadPreSafeArea()

        if !initialLoadingState {
            preLoadProjectsData()
            initialLoadingState = true
        }
        
        loadNews()
        restoreLastController()

        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        notesTable.keyboardDismissMode = .onDrag
        notesTable.contentInsetAdjustmentBehavior = .never
        notesTable.alwaysBounceVertical = true

        if #available(iOS 15.0, *) {
            sidebarTableView.sectionHeaderTopPadding = 0
        }

        super.viewDidLoad()
    }

    @objc public func didBecomeActive() {
        addPullTask()
    }

    public func scheduledGitPull() {
        // Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds

        gitPullTimer?.invalidate()
        gitPullTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.addPullTask), userInfo: nil, repeats: true)
    }
        
    public func startCloudDriveSyncEngine(completion: (() -> ())? = nil) {
        guard UserDefaultsManagement.iCloudDrive else { return }

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

    public func stopCloudDriveSyncEngine() {
        self.cloudDriveManager?.metadataQuery.stop()
    }

    public func configureUI() {
        UINavigationBar.appearance().isTranslucent = false

        self.metadataQueue.qualityOfService = .userInteractive
        self.indicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.large)

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .light, scale: .default)
        let appSettingsImage = UIImage(systemName: "sidebar.left", withConfiguration: config)?.imageWithColor(color1: UIColor.mainTheme)
        let appSettings = UIBarButtonItem(image: appSettingsImage, style: .plain, target: self, action: #selector(toggleSidebar))
        appSettings.tintColor = UIColor.mainTheme

        let generalSettingsImage = UIImage(systemName: "gear", withConfiguration: config)?.imageWithColor(color1: UIColor.mainTheme)
        let generalSettings = UIBarButtonItem(image: generalSettingsImage, style: .plain, target: self, action: #selector(openSettings))
        generalSettings.tintColor = UIColor.mainTheme

        navigationItem.leftBarButtonItems = [appSettings, generalSettings]

        setNavTitle(folder: NSLocalizedString("Inbox", comment: ""))
        sidebarTableView.backgroundColor = UIColor.sidebar

        loadPlusButton()

        notesTable.viewDelegate = self
        notesTable.dragInteractionEnabled = true
        notesTable.dragDelegate = notesTable
        sidebarTableView.dropDelegate = sidebarTableView

        notesTable.dataSource = notesTable
        notesTable.delegate = notesTable
        notesTable.layer.zPosition = 100
        notesTable.rowHeight = UITableView.automaticDimension
        notesTable.estimatedRowHeight = 160
    }

    public var lastSidebarItem: SidebarItem? = nil

    public func configureNavMenu(for sidebarItem: SidebarItem) {
        lastSidebarItem = sidebarItem

        let config = UIImage.SymbolConfiguration(pointSize: 23, weight: .light, scale: .default)
        let navSettingsImage = UIImage(systemName: "ellipsis.circle", withConfiguration: config)

        if #available(iOS 14.0, *) {
            let menu = makeSidebarSettingsMenu(for: sidebarItem)
            let navSettings = UIBarButtonItem(image: navSettingsImage, menu: menu)
            navSettings.tintColor = UIColor.mainTheme
            navigationItem.rightBarButtonItem = navSettings
            return
        }

        let navSettings = UIBarButtonItem(image: navSettingsImage, style: .plain, target: self, action: #selector(openSidebarSettings))
        navSettings.tintColor = UIColor.mainTheme
        navigationItem.rightBarButtonItem = navSettings
    }

    public func setNavTitle(folder: String? = nil, qty: String? = nil) {
        if let folder = folder {
            currentFolder = folder
        }

        if let qty = qty {
            folderCapacity = qty
        }

        let folder = currentFolder ?? ""
        var qty = folderCapacity ?? "∞"

        if let item = sidebarTableView.getSidebarItem()?.project, item.isCleanGit {
            qty += " | git ✓"
        }

        navigationItem.title = folder
    }

    public func configureNotifications() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(ubiquitousKeyValueStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default)

        if NSUbiquitousKeyValueStore.default.synchronize() == false {
            fatalError("This app was not built with the proper entitlement requests.")
        }
        
        NSUbiquitousKeyValueStore.default.synchronize()

        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: UIContentSizeCategory.didChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector:#selector(willExitForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    public func configureGestures() {
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(handleSidebarSwipe))
        swipe.minimumNumberOfTouches = 1
        swipe.delegate = self
        view.addGestureRecognizer(swipe)

        let longTapOnSidebar = UILongPressGestureRecognizer(target: self, action: #selector(sidebarLongPress))
        longTapOnSidebar.minimumPressDuration = 0.5
        view.addGestureRecognizer(longTapOnSidebar)

        let longTapOnNotes = UILongPressGestureRecognizer(target: self, action: #selector(notesLongPress))
        longTapOnNotes.minimumPressDuration = 0.5
        notesTable.addGestureRecognizer(longTapOnNotes)
        notesTable.dragInteractionEnabled = UserDefaultsManagement.sidebarIsOpened
    }

    public func configureSearchController() {
        let text = navigationItem.searchController?.searchBar.text

        let searchController = UISearchController(searchResultsController: nil)
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.placeholder = NSLocalizedString("Search or create", comment: "")
        searchController.searchBar.returnKeyType = .done
        searchController.searchBar.showsCancelButton = false
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.keyboardAppearance = traitCollection.userInterfaceStyle == .dark ? .dark : .default

        if let text = text {
            searchController.searchBar.text = text
        }

        navigationItem.searchController = searchController
    }

    public func enableSearchFocus() {
        searchFocus = true
    }

    public func disableSearchFocus() {
        searchFocus = false
    }

    @IBAction public func toggleSidebar() {
        if UserDefaultsManagement.sidebarIsOpened {
            hideSidebar()
        } else {
            showSidebar()
        }
    }

    @IBAction public func notesLongPress(gesture: UILongPressGestureRecognizer) {
        guard !UserDefaultsManagement.sidebarIsOpened else { return }

        let p = gesture.location(in: self.notesTable)

        if let indexPath = notesTable.indexPathForRow(at: p) {
            let note = notesTable.notes[indexPath.row]

            if gesture.state == .began {
                notesTable.actionsSheet(notes: [note], showAll: true, presentController: self)
            }
        }

        gesture.state = .ended
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
        reloadNotesTable() {
            self.stopAnimation(indicator: self.indicator)
        }
    }

    public func loadSidebar() {
        sidebarTableView.dataSource = self.sidebarTableView
        sidebarTableView.delegate = self.sidebarTableView
        sidebarTableView.viewController = self
        maxSidebarWidth = self.calculateLabelMaxWidth()

        lockedProject.layer.zPosition = 1001
        lockedProject.isUserInteractionEnabled = true
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(unlock))
        lockedProject.addGestureRecognizer(tapRecognizer)

        initSidebar()

        if UserDefaultsManagement.sidebarIsOpened {
            resizeSidebar()
        }

        guard Storage.shared().getRoot() != nil else { return }

//        DispatchQueue.main.async {
//            let inboxIndex = IndexPath(row: 0, section: 0)
//            self.sidebarTableView.tableView(self.sidebarTableView, didSelectRowAt: inboxIndex)
//        }
    }
    
    public func preLoadProjectsData() {
        guard storage.getRoot() != nil else { return }
        storage.loadInboxAndTrash()

        self.reloadNotesTable()

        DispatchQueue.global(qos: .userInteractive).async {
            let storage = self.storage

            let projectsLoading = Date()
            let results = storage.getProjectDiffs()

            OperationQueue.main.addOperation {
                self.sidebarTableView.removeRows(projects: results.0)
                self.sidebarTableView.insertRows(projects: results.1)
                self.notesTable.doVisualChanges(results: (results.2, results.3, []))
            }
            
            print("0. Projects diff loading finished in \(projectsLoading.timeIntervalSinceNow * -1) seconds")

            let diffLoading = Date()
            for project in storage.getProjects() {
                let changes = project.checkNotesCacheDiff()
                self.notesTable.doVisualChanges(results: changes)
                self.notesTable.hideLoader()
            }
            
            print("1. Notes diff loading finished in \(diffLoading.timeIntervalSinceNow * -1) seconds")

            // enable iCloud Drive updates after projects structure formalized
            self.cloudDriveManager?.metadataQuery.enableUpdates()

            let tagsPoint = Date()
            storage.loadNotesContent()

            DispatchQueue.main.async {

                self.importSavedInSharedExtension()

                self.sidebarTableView.reloadSidebar()
                self.resizeSidebar(withAnimation: true)
                self.sidebarTableView.loadAllTags()
            }

            print("2. Tags loading finished in \(tagsPoint.timeIntervalSinceNow * -1) seconds")

            // fill note from spotlight action
            if let restore = self.restoreActivity {
                if let note = Storage.shared().getBy(url: restore) {
                    DispatchQueue.main.async {
                        UIApplication.getEVC().load(note: note)
                    }
                }
            }
            
            if let restore = self.restoreFindID {
                self.restoreFindID = nil
                if let note = Storage.shared().getBy(title: restore) {
                    DispatchQueue.main.async {
                        UIApplication.getEVC().load(note: note)
                    }
                }
            }

            let spotlightPoint = Date()
            self.reIndexSpotlight()
            print("4. Spotlight indexation finished in \(spotlightPoint.timeIntervalSinceNow * -1) seconds")
            
            self.isLoadedDB = true
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
            if note.project.isTrash || !note.project.settings.showInCommon {
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
        guard storage.isReadedNewsOutdated(),
              let newsURL = storage.getNews(),
              let defaultProject = storage.getDefault() else { return }

        let isLandscape = UIDevice.current.orientation.isLandscape
        newsPopup?.removeFromSuperview()
        newsOverlay?.removeFromSuperview()

        let screeenWidth = UIScreen.main.bounds.width
        let screeenHeight = UIScreen.main.bounds.height

        let overlay = UIView(frame: CGRect(x: 0, y: 0, width: screeenWidth, height: screeenHeight))
        overlay.layer.zPosition = 104
        overlay.backgroundColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.5)
        UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.addSubview(overlay)
        self.newsOverlay = overlay

        var width = UIScreen.main.bounds.width - 20
        if isLandscape {
            width = UIScreen.main.bounds.width * 0.75
        }

        let height = screeenHeight * 0.75
        let note = Note(url: newsURL, with: defaultProject)
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

        let closeButton = UIButton(frame: CGRect(origin: CGPoint(x: width - 10 - 50, y: 10), size: CGSize(width: 50, height: 50)))
        let image = UIImage(named: "close-window.png")
        closeButton.setImage(image, for: UIControl.State.normal)
        closeButton.tintColor = UIColor.mainTheme
        closeButton.addTarget(self, action: #selector(closeNews), for: .touchDown)
        closeButton.layer.zPosition = 110
        news.addSubview(closeButton)

        UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.addSubview(news)

        self.newsPopup = news

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

    public func loadNotches() {
        rightPreSafeArea.backgroundColor = .whiteBlack
    }

    public func loadPreSafeArea() {
        if UserDefaultsManagement.sidebarIsOpened {
            // blue/black pre safe area
            leftPreSafeArea.backgroundColor = UIColor.sidebar
            rightPreSafeArea.backgroundColor = .whiteBlack
        } else {
            leftPreSafeArea.backgroundColor = .whiteBlack
            rightPreSafeArea.backgroundColor = .whiteBlack
        }
    }

    @objc public func openSettings() {
        navigationController?.interactivePopGestureRecognizer?.delegate = nil

        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc func ubiquitousKeyValueStoreDidChange(_ notification: NSNotification) {
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
                
                if key.startsWith(string: "es.fsnot.project-settings") {
                    let settingsKey = key.replacingOccurrences(of: "es.fsnot.project-settings", with: "")
                    if let project = storage.getProjectBy(settingsKey: settingsKey) {
                        project.reloadSettings()
                    }
                }
            }
        }
    }

    @objc func toggleSearch(refreshControl: UIRefreshControl) {
        if storage.hasOrigins() {
            addPullTask(force: true)
        } else {
            toggleSearchView()
        }
        
        refreshControl.endRefreshing()
    }
    
    @objc func addPullTask(force: Bool = false) {
        guard storage.hasOrigins() else { return }

        guard UIApplication.getVC().gitQueue.operationCount == 0 else {
            print("Pull skipped")
            return
        }

        let viewController = UIApplication.getVC()

        viewController.gitQueue.addOperation({
            Storage.shared().pullAll(force: force)

            if !UserDefaultsManagement.iCloudDrive {
                self.checkNew()
            }

            //            if viewController.gitQueueState.operationCount == 0 {
            //                viewController.gitQueueState.addOperation {
            //                    Storage.shared().checkGitState()
            //                    DispatchQueue.main.async {
            //                        self.updateNotesCounter()
            //                    }
            //                }
            //            }
        })
    }

    public func checkNew() {
        if let projects = Storage.shared().getGitProjects() {
            for project in projects {
                if let childProjects = project.getAllChild() {
                    for childProject in childProjects {
                        let changes = childProject.checkNotesCacheDiff(isGit: true)
                        self.notesTable.doVisualChanges(results: changes)
                    }
                }

                let changes = project.checkNotesCacheDiff(isGit: true)
                self.notesTable.doVisualChanges(results: changes)
            }
        }
    }

    public func loadSearchController(query: String? = nil) {
        if let query = query {
            navigationItem.searchController?.searchBar.text = query
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.navigationItem.searchController?.searchBar.becomeFirstResponder()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadPlusButton()
            }
        }

    }

    private func toggleSearchView() {
        loadSearchController()
        sidebarTableView.deselectAll()
        reloadNotesTable()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        buildSearchQuery()
        reloadNotesTable()
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {

        // hack for reinstantinate large title
        configureSearchController()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        notesTable.setContentOffset(CGPoint(x: 0, y: -44), animated: true)

        disableLockedProject()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let content = searchBar.text
        searchBar.text = ""
        self.createNote(content: content)
    }

    public func configureIndicator(indicator: UIActivityIndicatorView, view: UIView) {
        indicator.frame = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
        indicator.center = view.center
        indicator.layer.cornerRadius = 5
        indicator.layer.borderWidth = 1
        indicator.layer.borderColor = UIColor.lightGray.cgColor
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

    public func reloadNotesTable(completion: (() -> ())? = nil) {
        isActiveTableUpdating = true
        searchQueue.cancelAllOperations()
        setNavTitle(qty: "∞")
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

                if Storage.shared().searchQuery.isFit(note: note) {
                    notes.append(note)
                }
            }

            if let project = Storage.shared().searchQuery.projects.first, project.isLocked() {
                notes.removeAll()
            }

            var modifiedNotesList = [Note]()

            if !notes.isEmpty {
                modifiedNotesList = self.storage.sortNotes(noteList: notes)
            }

            if operation.isCancelled {
                completion?()
                return
            }

            DispatchQueue.main.async {
                self.setNavTitle(qty: String(notes.count))

                if DispatchTime.now() < self.accessTime {
                    completion?()
                    return
                }

                self.notesTable.notes = modifiedNotesList
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
            self.setNavTitle(qty: String(self.notesTable.notes.count))
        }
    }

    public func isNoteInsertionAllowed() -> Bool {
        if let searchBar = getSearchBar() {
            return !searchBar.isFirstResponder
        }

        return true
    }

    public func getSearchBar() -> UISearchBar? {
        return navigationItem.searchController?.searchBar 
    }

    func loadPlusButton() {
        if let button = getButton(tag: 1) {
            let width = self.view.frame.width
            let height = self.view.frame.height

            button.frame = CGRect(origin: CGPoint(x: CGFloat(width - 85), y: CGFloat(height - 85)), size: CGSize(width: 60, height: 60))
            return
        }

        let button = UIButton(frame: CGRect(origin: CGPoint(x: self.view.frame.width - 85, y: self.view.frame.height - 85), size: CGSize(width: 60, height: 60)))

        var image = UIImage()
        if #available(iOS 15.0, *) {
            let colorsConfig = UIImage.SymbolConfiguration(paletteColors: [.white, UIColor.mainTheme])
            if let imageUnwrapped = UIImage(systemName: "plus.circle.fill", withConfiguration: colorsConfig)?.resize(maxWidthHeight: 60) {
                image = imageUnwrapped
            }
        } else {
            if let imageUnwrapped = UIImage(systemName: "plus.circle.fill")?.withTintColor(UIColor.mainTheme).resize(maxWidthHeight: 60) {
                image = imageUnwrapped
            }
        }

        button.setImage(image, for: UIControl.State.normal)
        button.tag = 1
        button.addTarget(self, action: #selector(self.newButtonAction), for: .touchUpInside)
        button.layer.zPosition = 101
        self.view.addSubview(button)
    }

    public func getButton(tag: Int) -> UIButton? {
        for sub in self.view.subviews {

            if sub.tag == tag {
                return sub as? UIButton
            }
        }

        return nil
    }

    @objc func newButtonAction() {
        if let project = sidebarTableView.getSidebarProjects()?.first, project.isEncrypted, project.password == nil {
            unlockProject(selectedProject: project, createNote: true)
            return
        }

        createNote(content: nil)
    }

    @objc public func closeNews() {
        newsPopup?.removeFromSuperview()
        newsOverlay?.removeFromSuperview()

        // mark as read
        UserDefaultsManagement.lastNews = storage.getNewsDate()
    }

    public func createNote(content: String? = nil, pasteboard: Bool = false) {
        var currentProject: Project
        if let project = storage.getProjects().first {
            currentProject = project
        } else {
            return
        }

        if let item = self.sidebarTableView.getSidebarItem(),
            let project = item.project,
            !project.isTrash,
            !project.isVirtual {
            currentProject = project
        }

        let note = Note(name: "", project: currentProject)
        if let content = content {
            note.content = NSMutableAttributedString(string: content)
        }

        var selectedRange: NSRange?
        if pasteboard {
            if  let image = UIPasteboard.general.image,
                let data = image.jpegData(compressionQuality: 1),
                let imagePath = ImagesProcessor.writeFile(data: data, note: note)
            {
                let string = "![](\(imagePath))\n\n"
                note.content = NSMutableAttributedString(string: string)
                selectedRange = NSRange(location: string.count, length: 0)
            } else if let content = UIPasteboard.general.string {
                note.content = NSMutableAttributedString(string: content)
                selectedRange = NSRange(location: content.count, length: 0)
            }
        }
        
        note.save()

        let storage = Storage.shared()
        storage.add(note)

        let evc = UIApplication.getEVC()
        evc.note = note
        evc.fill(note: note, selectedRange: selectedRange)

        openEditorViewController()

        if self.isActiveTableUpdating {
            self.delayedInsert = note
        } else {
            notesTable.insertRows(notes: [note])
            notesTable.scrollTo(note: note)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let evc = UIApplication.getEVC()
            if note.previewState {
                evc.togglePreview()
            }
            evc.editArea.becomeFirstResponder()

            if let password = note.project.password {
                if note.encrypt(password: password) {
                    if note.unLock(password: password) {
                        note.password = password
                    }
                }
            }
        }
    }

    public func openEditorViewController() {
        navigationController?.interactivePopGestureRecognizer?.delegate = nil

        if let controllers = navigationController?.viewControllers {
            for controller in controllers {
                if let _ = controller as? EditorViewController {
                    return
                }
            }
        }

        let evc = UIApplication.getEVC()
        editorViewController = evc
        
        navigationController?.pushViewController(evc, animated: true)
    }

    public func popViewController() {
        navigationController?.popViewController(animated: true)
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
    }

    public func importSavedInSharedExtension() {
        var notes = [Note]()
        
        for url in UserDefaultsManagement.importURLs {
            if let note = storage.importNote(url: url) {
                notes.append(note)
            }
        }
        
        notesTable.insertRows(notes: notes)

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

            DispatchQueue.main.async {
                self.loadPlusButton()
                self.loadNews()
            }
        }
    }

    @objc func willExitForeground() {
        importSavedInSharedExtension()
    }

    @objc func handleSidebarSwipe(_ swipe: UIPanGestureRecognizer) {
        let notchWidth = getLeftInset()
        let translation = swipe.translation(in: notesTable)

        if swipe.state == .began {
            sidebarTableView.isUserInteractionEnabled = true
            initSidebar()
            return
        }

        if swipe.state == .changed {
            guard
                UserDefaultsManagement.sidebarIsOpened && translation.x + notchWidth < 0 && (translation.x + notchWidth + maxSidebarWidth) > 0
                || !UserDefaultsManagement.sidebarIsOpened && translation.x + notchWidth > 0 && translation.x + notchWidth < maxSidebarWidth
            else { return }

            UIView.animate(withDuration: 0.075, delay: 0.0, options: .beginFromCurrentState, animations: {
                if translation.x + notchWidth > 0 {
                    self.notesTableLeadingConstraint.constant = translation.x
                    self.sidebarTableLeadingConstraint.constant = -self.maxSidebarWidth/2 + translation.x/2
                } else {
                    self.notesTableLeadingConstraint.constant = self.maxSidebarWidth + translation.x
                    self.sidebarTableLeadingConstraint.constant = translation.x/2
                }
                self.view.layoutIfNeeded()
            })
            return
        }

        if swipe.state == .ended {
            if translation.x > 0 {
                showSidebar()
            }

            if translation.x < 0 {
                hideSidebar()
            }
        }
    }

    private func initSidebar() {
        if UserDefaultsManagement.sidebarIsOpened {
            self.sidebarTableLeadingConstraint.constant = 0
            self.notesTableLeadingConstraint.constant = self.maxSidebarWidth

            self.notesTable.dragInteractionEnabled = true
            self.sidebarTableView.isUserInteractionEnabled = true
        } else {
            self.notesTableLeadingConstraint.constant = 0
            self.sidebarTableLeadingConstraint.constant = -self.maxSidebarWidth

            // blue/blck pre safe area
            leftPreSafeArea.backgroundColor = UIColor.sidebar

            self.notesTable.dragInteractionEnabled = false
            self.sidebarTableView.isUserInteractionEnabled = false
        }
    }

    private func showSidebar() {
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .init(), animations: {
            self.notesTableLeadingConstraint.constant = self.maxSidebarWidth
            self.sidebarTableLeadingConstraint.constant = 0
            self.sidebarTableWidth.constant = self.maxSidebarWidth
            self.view.layoutIfNeeded()
        }) { _ in
            UserDefaultsManagement.sidebarIsOpened = true

            self.notesTable.dragInteractionEnabled = true
            self.sidebarTableView.isUserInteractionEnabled = true

            self.leftPreSafeArea.backgroundColor = UIColor.sidebar
        }
    }

    private func hideSidebar() {
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .init(), animations: {
            self.notesTableLeadingConstraint.constant = 0
            self.sidebarTableLeadingConstraint.constant = -self.maxSidebarWidth
            self.view.layoutIfNeeded()
        }) { _ in
            UserDefaultsManagement.sidebarIsOpened = false

            self.notesTable.dragInteractionEnabled = false
            self.sidebarTableView.isUserInteractionEnabled = false

            // white pre safe area
            self.leftPreSafeArea.backgroundColor = .whiteBlack
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            notesTableBottomContraint.constant = keyboardSize.height
            sidebarTableBottomConstraint.constant = keyboardSize.height
            loadPlusButton()
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        notesTableBottomContraint.constant = 0
        sidebarTableBottomConstraint.constant = 0
        loadPlusButton()
    }

    public func refreshTextStorage(note: Note) {
        DispatchQueue.main.async {
            UIApplication.getEVC().fill(note: note)
        }
    }

    private func calculateLabelMaxWidth() -> CGFloat {
        var width = CGFloat(0)
        var font = UIFont(name: "HelveticaNeue-BoldItalic", size: 15)
        let fontMetrics = UIFontMetrics(forTextStyle: .title3)
        font = fontMetrics.scaledFont(for: font!)

        let settings = NSLocalizedString("Settings", comment: "Sidebar settings")
        let untagged = NSLocalizedString("Untagged", comment: "Sidebar settings")
        let inbox = NSLocalizedString("Inbox", comment: "Inbox in sidebar")
        let notes = NSLocalizedString("Notes", comment: "Notes in sidebar")
        let todo = NSLocalizedString("Todo", comment: "Todo in sidebar")
        let trash = NSLocalizedString("Trash", comment: "Trash in sidebar")

        var sidebarItems = [String]()
        var tags = [String]()

        if let project = storage.searchQuery.projects.first {
            tags = sidebarTableView.getAllTags(projects: [project])
        }

        sidebarItems = tags + Storage.shared().getProjects().map({ $0.label })
            + [settings, inbox, notes, todo, trash, untagged]

        for item in sidebarItems {
            let labelWidth = (item as NSString).size(withAttributes: [.font: font]).width + 60

            if labelWidth < (view.frame.size.width / 2) {
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
            self.unLock(notes: notes, completion: completion, password: password)
        }
    }

    public func unLock(notes: [Note], completion: @escaping ([Note]?) -> (), password: String) {
        for note in notes {
            var success = [Note]()
            if note.unLock(password: password) {
                note.password = password
                success.append(note)
            }

            DispatchQueue.main.async {
                self.notesTable.reloadRowForce(note: note)
            }

            completion(success)
        }
    }

    public func toggleNotesLock(notes: [Note]) {
        var notes = notes

        notes = lockUnlocked(notes: notes)
        guard notes.count > 0 else { return }

        getMasterPassword() { password in
            for note in notes {
                if note.container == .encryptedTextPack {
                    if note.unLock(password: password) {
                        note.password = password

                        DispatchQueue.main.async {
                            self.notesTable.reloadRowForce(note: note)
                            UIApplication.getEVC().fill(note: note)
                            UIApplication.getVC().openEditorViewController()
                        }
                    }
                } else {
                    if note.encrypt(password: password) {
                        note.password = nil

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
                    note.password = nil

                    notesTable.reloadRowForce(note: note)
                }
                notes.removeAll { $0 === note }
            }
            isFirst = false
        }

        return notes
    }

    public func getMasterPassword(isUnlock: Bool = false, completion: @escaping (String) -> ()) {
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
            let title = NSLocalizedString("Master password:", comment: "")
            let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

            alertController.addTextField(configurationHandler: {
                [] (textField: UITextField) in
                textField.placeholder = "mast3r passw0rd"
            })

            let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
                guard let password = alertController.textFields?[0].text, password.count > 0 else {
                    return
                }

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

    public func unlockPasswordPrompt(completion: @escaping (String) -> ()) {
        DispatchQueue.main.async {
            let title = NSLocalizedString("Password:", comment: "")
            let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

            alertController.addTextField(configurationHandler: {
                [] (textField: UITextField) in
                textField.placeholder = "note passw0rd"
                textField.isSecureTextEntry = true
            })

            let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
                guard let password = alertController.textFields?[0].text, password.count > 0 else {
                    return
                }

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

    public func resizeSidebar(withAnimation: Bool = false) {
        let width = calculateLabelMaxWidth()
        maxSidebarWidth = width

        guard UserDefaultsManagement.sidebarIsOpened else { return }

        if maxSidebarWidth > view.frame.size.width {
            maxSidebarWidth = view.frame.size.width / 2
        }

        if (withAnimation) {
            UIView.animate(withDuration: 0.3, delay: 0, options: .beginFromCurrentState, animations: {
                let width = self.maxSidebarWidth
                self.notesTableLeadingConstraint.constant = width
                self.sidebarTableLeadingConstraint.constant = 0
                self.sidebarTableWidth.constant = width
            }) { _ in

            }
        } else {
            notesTableLeadingConstraint.constant = maxSidebarWidth
            sidebarTableWidth.constant = notesTableLeadingConstraint.constant
        }
    }

    public func restoreLastController() {
        guard !Storage.shared().isCrashedLastTime else { return }

        DispatchQueue.main.async {
            if let noteURL = UserDefaultsManagement.currentNote {
                if FileManager.default.fileExists(atPath: noteURL.path),
                   let project = Storage.shared().getProjectByNote(url: noteURL)
                {
                    var note = Storage.shared().getBy(url: noteURL)

                    if note == nil {
                        note = Note(url: noteURL, with: project)
//                        if let unwrapped = note {
//                            Storage.shared().add(unwrapped)
//                        }
                    }

                    guard let note = note, !note.isEncrypted()  else { return }

                    UIApplication.getVC().openEditorViewController()

                    let evc = UIApplication.getEVC()
                    evc.fill(note: note)

                    if UserDefaultsManagement.currentEditorState == true,
                       let selectedRange = UserDefaultsManagement.currentRange,
                       !note.previewState
                    {
                        if selectedRange.upperBound <= note.content.length {
                            evc.editArea.selectedRange = selectedRange
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            evc.editArea.becomeFirstResponder()
                        }
                    }

                    UserDefaultsManagement.currentNote = nil
                }
            }
        }
    }
    
    public func reloadDatabase() {
        Storage.instance = nil

        storage = Storage.shared()
        sidebarTableView.reloadSidebar()
        viewDidLoad()
    }

    public func enableLockedProject() {
        lockedProject.isHidden = false
        clean()
    }

    public func disableLockedProject() {
        lockedProject.isHidden = true
    }

    public func clean() {
        notesTable.notes.removeAll()
        notesTable.reloadData()
    }

    public func showAlert(message: String) {
        DispatchQueue.main.async {
            let title = NSLocalizedString("Web sharing error", comment: "")
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let confirmAction = UIAlertAction(title: "OK", style: .default)
            alertController.addAction(confirmAction)
            self.present(alertController, animated: true)
        }
    }

    public func buildSearchQuery() {
        let searchQuery = SearchQuery()

        var projects = [Project]()
        var tags = [String]()
        var type: SidebarItemType?

        if let sidebarTableView = self.sidebarTableView, let indexPaths = sidebarTableView.indexPathsForSelectedRows {

            for indexPath in indexPaths {
                let item = sidebarTableView.sidebar.items[indexPath.section][indexPath.row]

                if let project = item.project, !project.isVirtual {
                    projects.append(project)
                }

                if item.type == .Tag {
                    tags.append(item.name)
                }

                if item.type == .All ||
                    item.type == .Untagged ||
                    item.type == .Todo ||
                    item.type == .Trash ||
                    item.type == .Inbox {

                    type = item.type
                }
            }
        }

        if projects.count == 0 && type == nil {
            type = .All
        }

        let filter = getSearchBar()?.text ?? ""

        searchQuery.projects = projects
        searchQuery.tags = tags
        searchQuery.setFilter(filter)

        if let type = type {
            searchQuery.setType(type)
        }

        self.storage.setSearchQuery(value: searchQuery)
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
