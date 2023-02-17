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

    private var newsPopup: MPreviewView?
    private var newsOverlay: UIView?

    public var indicator: UIActivityIndicatorView?

    public var storage = Storage.shared()
    public var cloudDriveManager: CloudDriveManager?

    private let searchQueue = OperationQueue()
    private let metadataQueue = OperationQueue()
    
    public let gitQueue = OperationQueue()
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

    // Last selected project abd tag in sidebar
    public var searchQuery: SearchQuery = SearchQuery(type: .Inbox)
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

        super.viewDidAppear(animated)
    }

    override func viewDidLoad() {
        loadInbox()

        startCloudDriveSyncEngine()

        configureUI()
        configureNotifications()
        configureGestures()
        configureSearchController()
        
        gitQueue.qualityOfService = .userInteractive
        gitQueue.maxConcurrentOperationCount = 1
        
        GitViewController.installGitKey()
        scheduledGitPull()

        loadNotesTable()
        loadSidebar()

        loadNotches()
        loadPreSafeArea()

        preLoadProjectsData()
        loadNews()
        restoreLastController()

        super.viewDidLoad()
    }

    public func scheduledGitPull() {
        // Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds
        gitPullTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.addPullTask), userInfo: nil, repeats: true)
    }
    
    public func stopGitPull() {
        gitPullTimer?.invalidate()
        gitPullTimer = nil
    }
    
    public func loadInbox() {
        guard let project = storage.getDefault() else { return }

        project.loadNotes()
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

        if UserDefaultsManagement.isFirstLaunch {
            UserDefaultsManagement.fontName = "Avenir Next"
            UserDefaultsManagement.isFirstLaunch = false
        }

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

        let navSettingsImage = UIImage(named: "more_row_action")!.resize(maxWidthHeight: 34)?.imageWithColor(color1: .white)
        let navSettings = UIBarButtonItem(image: navSettingsImage, style: .plain, target: self, action: #selector(openSidebarSettings))
        navSettings.tintColor = .white

        let appSettingsImage = UIImage(named: "hideSide")?.resize(maxWidthHeight: 30)?.imageWithColor(color1: .white)
        let appSettings = UIBarButtonItem(image: appSettingsImage, style: .plain, target: self, action: #selector(toggleSidebar))
        appSettings.tintColor = .white

        let searchButtonImage = UIImage(named: "searchButton")?.resize(maxWidthHeight: 25)?.imageWithColor(color1: .white)
        let searchButton = UIBarButtonItem(image: searchButtonImage, style: .plain, target: self, action: #selector(openSearchController))
        searchButton.tintColor = .white
        searchButton.imageInsets = UIEdgeInsets(top: 0.0, left: 20, bottom: 0, right: 0)

        let generalSettingsImage = UIImage(named: "navigationSettings")?.resize(maxWidthHeight: 23)?.imageWithColor(color1: .white)
        let generalSettings = UIBarButtonItem(image: generalSettingsImage, style: .plain, target: self, action: #selector(openSettings))
        generalSettings.tintColor = .white

        navigationItem.leftBarButtonItems = [appSettings, generalSettings]
        navigationItem.rightBarButtonItems = [navSettings, searchButton]

        setNavTitle(folder: NSLocalizedString("Inbox", comment: ""))

        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x000000)
        notesTable.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x000000)

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

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(toggleSearch), for: .valueChanged)

        notesTable.refreshControl = refreshControl
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
        
        if gitClean {
            qty += " | git ✓"
        }

        let titleParameters = [NSAttributedString.Key.foregroundColor : UIColor.white]
        let subtitleParameters = [NSAttributedString.Key.foregroundColor : UIColor.white, .font: UIFont(name: "Source Code Pro", size: 10)]
        let title: NSMutableAttributedString = NSMutableAttributedString(string: folder, attributes: titleParameters)
        let subtitle: NSAttributedString = NSAttributedString(string: qty, attributes: subtitleParameters as [NSAttributedString.Key : Any])

        title.append(NSAttributedString(string: "\n"))
        title.append(subtitle)

        let size = title.size()

        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        titleLabel.attributedText = title
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        navigationItem.titleView = titleLabel
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

        let longTapOnNotes = UILongPressGestureRecognizer(target: self, action: #selector(notesLongPress))
        longTapOnNotes.minimumPressDuration = 0.5
        notesTable.addGestureRecognizer(longTapOnNotes)
        notesTable.dragInteractionEnabled = UserDefaultsManagement.sidebarIsOpened
    }

    public func configureSearchController() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = NSLocalizedString("Search or create", comment: "")
        searchController.searchBar.mixedBackgroundColor = Colors.Header
        searchController.searchBar.mixedBarTintColor = MixedColor(normal: 0xffffff, night: 0xffffff)
        
        if let textFieldInsideSearchBar = searchController.searchBar.value(forKey: "searchField") as? UITextField {
            textFieldInsideSearchBar.attributedPlaceholder = NSAttributedString(string: textFieldInsideSearchBar.placeholder ?? "", attributes: [NSAttributedString.Key.foregroundColor : UIColor.gray])
        }
        
        searchController.searchBar.returnKeyType = .go
        searchController.searchBar.showsCancelButton = true
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.keyboardAppearance = NightNight.theme == .night ? .dark : .default

        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

        if let textFieldInsideSearchBar = searchController.searchBar.value(forKey: "searchField") as? UITextField,
           let glassIconView = textFieldInsideSearchBar.leftView as? UIImageView {
            glassIconView.image = glassIconView.image?.withRenderingMode(.alwaysTemplate)
            glassIconView.tintColor = .white

            textFieldInsideSearchBar.keyboardAppearance = NightNight.theme == .night ? .dark : .default
        }

        self.searchController = searchController

        navigationItem.hidesSearchBarWhenScrolling = false
    }

    @IBAction public func openSearchController() {
        loadSearchController()
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
        reloadNotesTable(with: SearchQuery(type: .Inbox)) {
            self.stopAnimation(indicator: self.indicator)
        }
    }

    public func loadSidebar() {
        sidebarTableView.dataSource = self.sidebarTableView
        sidebarTableView.delegate = self.sidebarTableView
        sidebarTableView.viewController = self
        maxSidebarWidth = self.calculateLabelMaxWidth()

        initSidebar()

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

    public func loadNotches() {
        rightPreSafeArea.mixedBackgroundColor =
            MixedColor(
                normal: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.00),
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
        }
    }

    @objc public func openSettings() {
        navigationController?.interactivePopGestureRecognizer?.delegate = nil

        navigationController?.pushViewController(SettingsViewController(), animated: true)
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

    @objc func toggleSearch(refreshControl: UIRefreshControl) {
        if UserDefaultsManagement.gitVersioning {
            addPullTask()
        } else {
            toggleSearchView()
        }
        
        refreshControl.endRefreshing()
    }
    
    @objc func addPullTask() {
        guard UserDefaultsManagement.gitVersioning else { return }
        
        UIApplication.getVC().gitQueue.addOperation({
            Storage.shared().pullAll()
            
            self.gitClean = Storage.shared().getDefault()?.isCleanRepo() == true
            self.updateNotesCounter()
        })
    }

    public func loadSearchController(query: String? = nil) {
        navigationItem.searchController = searchController

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

    public func unloadSearchController() {
        navigationItem.searchController = nil

        sidebarTableView.restoreSelection(for: searchQuery)
        reloadNotesTable(with: searchQuery)

        // iOS 12 compatibility
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadPlusButton()
        }
    }

    public func callbackSearchController() {
        if shouldReturnToControllerIndex {
            shouldReturnToControllerIndex = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.openEditorViewController()

                UIApplication.getEVC().refill()
            }
        }
    }

    private func toggleSearchView() {

        if navigationItem.searchController != nil {
            unloadSearchController()
            return
        }

        loadSearchController()

        sidebarTableView.deselectAll()
        reloadNotesTable(with: SearchQuery())
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard searchText.count > 0 else {
            reloadNotesTable(with: SearchQuery())
            return
        }

        reloadNotesTable(with: SearchQuery(filter: searchText))
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        unloadSearchController()
        callbackSearchController()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let content = searchBar.text
        searchBar.text = ""
        self.createNote(content: content, pasteboard: nil)
        unloadSearchController()
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

                if self.isFit(note: note, searchQuery: query) {
                    notes.append(note)
                }
            }

            var modifiedNotesList = [Note]()

            if !notes.isEmpty {
                modifiedNotesList =
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
        if let searchBar = navigationItem.searchController?.searchBar {
            return !searchBar.isFirstResponder
        }

        return true
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
            || searchQuery.type == .Untagged && note.tags.count == 0
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

    func loadPlusButton() {
        if let button = getButton(tag: 1) {
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

    private func getButton(tag: Int) -> UIButton? {
        for sub in self.view.subviews {

            if sub.tag == tag {
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

        note.write()

        if pasteboard != nil {
            savePasteboard(note: note)
        }

        let storage = Storage.shared()
        storage.add(note)

        let evc = UIApplication.getEVC()
        evc.note = note
        evc.fill(note: note)

        openEditorViewController()

        if self.isActiveTableUpdating {
            self.delayedInsert = note
        } else {
            notesTable.insertRows(notes: [note])
            notesTable.scrollTo(note: note)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let evc = UIApplication.getEVC()
            if UserDefaultsManagement.previewMode {
                evc.togglePreview()
            }
            evc.editArea.becomeFirstResponder()
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

            DispatchQueue.main.async {
                self.loadPlusButton()
                self.loadNews()
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
            UIApplication.getNC()?.disableNightMode()
            return
        }

        if (UserDefaultsManagement.maxNightModeBrightnessLevel > brightness && NightNight.theme == .normal) {
            UIApplication.getNC()?.enableNightMode()
        }
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
        } else {
            self.notesTableLeadingConstraint.constant = 0
            self.sidebarTableLeadingConstraint.constant = -self.maxSidebarWidth

            // blue/blck pre safe area
            leftPreSafeArea.mixedBackgroundColor =
                MixedColor(
                    normal: UIColor(red: 0.27, green: 0.51, blue: 0.64, alpha: 1.00),
                    night: UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.00)
                )
        }
    }

    private func showSidebar() {
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .init(), animations: {
            self.notesTableLeadingConstraint.constant = self.maxSidebarWidth
            self.sidebarTableLeadingConstraint.constant = 0
            self.view.layoutIfNeeded()
        }) { _ in
            UserDefaultsManagement.sidebarIsOpened = true

            self.notesTable.dragInteractionEnabled = true
            self.sidebarTableView.isUserInteractionEnabled = true

            self.leftPreSafeArea.mixedBackgroundColor =
                MixedColor(
                    normal: UIColor(red: 0.27, green: 0.51, blue: 0.64, alpha: 1.00),
                    night: UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.00)
                )
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
            self.leftPreSafeArea.mixedBackgroundColor =
                MixedColor(
                    normal: .white,
                    night: .black
            )
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
            + Storage.shared().getProjects().map({ $0.label })
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
                    self.savePassword(password)
                    note.password = password
                    
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

                        self.savePassword(password)
                    }
                } else {
                    if note.encrypt(password: password) {
                        self.savePassword(password)
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

    public func savePassword(_ value: String) {
        let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")
        do {
           try item.savePassword(value)
        } catch {}
    }

    public func resizeSidebar(withAnimation: Bool = false) {
        let currentSidebarWidth = self.sidebarTableWidth.constant
        let width = calculateLabelMaxWidth()
        maxSidebarWidth = width

        if maxSidebarWidth < currentSidebarWidth {
            return
        }
        
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
                        if let unwrapped = note {
                            Storage.shared().add(unwrapped)
                        }
                    }

                    guard let note = note, !note.isEncrypted()  else { return }

                    UIApplication.getVC().openEditorViewController()

                    let evc = UIApplication.getEVC()
                    evc.fill(note: note)

                    if UserDefaultsManagement.currentEditorState == true,
                       let selectedRange = UserDefaultsManagement.currentRange,
                       !UserDefaultsManagement.previewMode
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

extension UISearchBar {
    func setPlaceholderTextColorTo(color: UIColor) {
        let textFieldInsideSearchBar = self.value(forKey: "searchField") as? UITextField
        textFieldInsideSearchBar?.textColor = color
        let textFieldInsideSearchBarLabel = textFieldInsideSearchBar!.value(forKey: "placeholderLabel") as? UILabel
        textFieldInsideSearchBarLabel?.textColor = color
    }
}
