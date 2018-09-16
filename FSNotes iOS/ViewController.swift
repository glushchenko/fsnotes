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

    @IBOutlet weak var currentFolder: UILabel!
    @IBOutlet weak var folderCapacity: UILabel!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var search: UISearchBar!
    @IBOutlet weak var searchCancel: UIButton!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var searchView: UIView!
    @IBOutlet var notesTable: NotesTableView!
    @IBOutlet weak var sidebarTableView: SidebarTableView!
    @IBOutlet weak var sidebarWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var noteTableViewLeadingConstraint: NSLayoutConstraint!

    public let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)

    public var storage: Storage?
    public var cloudDriveManager: CloudDriveManager?

    private let searchQueue = OperationQueue()
    private var delayedInsert: Note?

    private var filteredNoteList: [Note]?
    private var maxSidebarWidth = CGFloat(0)

    public var is3DTouchShortcut = false
    private var isActiveTableUpdating = false

    override func viewDidLoad() {
        UIApplication.shared.statusBarStyle = MixedStatusBarStyle(normal: .default, night: .lightContent).unfold()

        self.searchButton.setMixedImage(MixedImage(normal: UIImage(named: "search")!, night: UIImage(named: "search_white")!), forState: .normal)

        self.settingsButton.setMixedImage(MixedImage(normal: UIImage(named: "settings")!, night: UIImage(named: "settings_white")!), forState: .normal)

        self.headerView.mixedBackgroundColor = Colors.Header
        self.searchView.mixedBackgroundColor = Colors.Header

        self.search.mixedBackgroundColor = Colors.Header
        self.search.mixedBarTintColor = Colors.Header

        self.folderCapacity.mixedTextColor = Colors.titleText
        self.currentFolder.mixedTextColor = Colors.titleText

        self.searchCancel.mixedTintColor = Colors.buttonText
        self.search.mixedKeyboardAppearance = MixedKeyboardAppearance.init(normal: .light, night: .dark)

        view.mixedBackgroundColor = MixedColor(normal: 0xfafafa, night: 0x47444e)

        notesTable.mixedBackgroundColor = MixedColor(normal: 0xffffff, night: 0x2e2c32)

        let searchBarTextField = search.value(forKey: "searchField") as? UITextField
        searchBarTextField?.mixedTextColor = MixedColor(normal: 0x000000, night: 0xfafafa)

        loadPlusButton()

        search.delegate = self
        search.autocapitalizationType = .none

        notesTable.viewDelegate = self
        notesTable.dataSource = notesTable
        notesTable.delegate = notesTable
        notesTable.layer.zPosition = 100

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(togglseSearch), for: .valueChanged)

        notesTable.refreshControl = refreshControl

        sidebarTableView.dataSource = sidebarTableView
        sidebarTableView.delegate = sidebarTableView
        sidebarTableView.viewController = self

        UserDefaultsManagement.fontSize = 17
        self.storage = Storage.sharedInstance()

        guard let storage = self.storage else { return }

        if storage.noteList.count == 0 {
            DispatchQueue.global().async {
                storage.initiateCloudDriveSync()
            }

            storage.loadDocuments() {
                DispatchQueue.main.async {
                    self.reloadSidebar()
                }
            }

            self.configureIndicator()
            DispatchQueue.main.async {
                self.initTableData()
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
        super.viewDidLoad()
    }

    private func reloadSidebar() {
        self.sidebarTableView.sidebar = Sidebar()
        self.maxSidebarWidth = self.calculateLabelMaxWidth()
        self.sidebarTableView.reloadData()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = gestureRecognizer as? UIPanGestureRecognizer {
            if recognizer.translation(in: self.view).x > 0 || sidebarTableView.frame.width != 0 {
                return true
            }
        }
        return false
    }

    override var preferredStatusBarStyle : UIStatusBarStyle {
        return MixedStatusBarStyle(normal: .default, night: .lightContent).unfold()
    }

    @IBAction func openSearchView(_ sender: Any) {
        self.toggleSearchView()
    }

    @IBAction func hideSearchView(_ sender: Any) {
        self.toggleSearchView()
    }

    @IBAction func openSettings(_ sender: Any) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let sourceSelectorTableViewController = storyBoard.instantiateViewController(withIdentifier: "settingsViewController") as! SettingsViewController
        let navigationController = UINavigationController(rootViewController: sourceSelectorTableViewController)

        self.present(navigationController, animated: true, completion: nil)
    }


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
                if let isPinned = keyStore.object(forKey: key) as? Bool, let note = self.storage?.getBy(name: key) {
                    note.isPinned = isPinned
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
            self.viewWillAppear(false)
        } else {
            self.searchView.isHidden = true
            self.search.endEditing(true)
            self.search.text = nil
            self.updateTable {}
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

    private func configureIndicator() {
        self.indicator.color = NightNight.theme == .night ? UIColor.white : UIColor.black
        self.indicator.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 40.0)
        self.indicator.center = self.view.center
        self.view.addSubview(self.indicator)
        self.indicator.bringSubview(toFront: self.view)
        self.indicator.startAnimating()
        self.indicator.layer.zPosition = 101
    }

    public func initTableData() {
        guard let storage = self.storage else { return }

        self.updateTable() {
            self.indicator.stopAnimating()
            self.indicator.layer.zPosition = -1
            self.reloadSidebar()
            self.cloudDriveManager = CloudDriveManager(delegate: self, storage: storage)

            if !self.is3DTouchShortcut, let note = Storage.sharedInstance().noteList.first {
                let evc = self.getEVC()
                evc?.fill(note: note)
            }
        }
    }

    public func updateTable(search: Bool = false, completion: @escaping () -> Void) {
        self.isActiveTableUpdating = true
        self.searchQueue.cancelAllOperations()

        guard let storage = self.storage else { return }

        let filter = self.search.text!

        var type: SidebarItemType? = nil
        var terms = filter.split(separator: " ")

        let sidebarItem = getSidebarItem()

        if let si = sidebarItem {
            type = si.type
        }

        if let type = type, type == .Todo {
            terms.append("- [ ]")
        }

        let operation = BlockOperation()
        operation.addExecutionBlock {

            let source = storage.noteList
            var notes = [Note]()

            for note in source {
                if operation.isCancelled {
                    break
                }

                if (
                    !note.name.isEmpty
                        && (
                            filter.isEmpty && type != .Todo || type == .Todo && (
                                self.isMatched(note: note, terms: ["- [ ]"])
                                    || self.isMatched(note: note, terms: ["- [x]"])
                                )
                                || self.isMatched(note: note, terms: terms)
                        ) && (
                            self.isFit(note: note, sidebarItem: sidebarItem)
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
                    self.notesTable.notes = storage.sortNotes(noteList: notes, filter: "")
                }
            } else {
                self.notesTable.notes.removeAll()
            }

            if operation.isCancelled {
                completion()
                return
            }

            DispatchQueue.main.async {
                self.notesTable.reloadData()

                if let note = self.delayedInsert {
                    self.notesTable.insertRow(note: note)
                    self.delayedInsert = nil
                }

                self.isActiveTableUpdating = false
                completion()
            }
        }

        self.searchQueue.addOperation(operation)
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

    private func isFit(note: Note, sidebarItem: SidebarItem? = nil) -> Bool {
        var type: SidebarItemType? = nil
        var project: Project? = nil
        var sidebarName = ""

        if let sidebarItem = sidebarItem {
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
        updateTable(search: true, completion: {})
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let name = searchBar.text, name.count > 0 else {
            searchBar.endEditing(true)
            return
        }
        guard let project = self.storage?.getProjects().first else { return }

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

    func createNote(content: String? = nil) {
        var currentProject: Project
        var tag: String?

        if let project = self.storage?.getProjects().first {
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

        let document = UINote(fileURL: note.url, textWrapper: note.getFileWrapper())
        document.save()

        let storage = Storage.sharedInstance()
        storage.add(note)

        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? UINavigationController, let evc = viewController.viewControllers[0] as? EditorViewController else {
            return
        }

        pageController.switchToEditor()

        evc.note = note
        evc.fill(note: note)
        evc.editArea.becomeFirstResponder()

        if self.isActiveTableUpdating {
            self.delayedInsert = note
        } else {
            self.notesTable.insertRow(note: note)
        }
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

            vc.sidebarTableView.backgroundColor = UIColor(red:0.19, green:0.21, blue:0.21, alpha:1.0)
            vc.sidebarTableView.updateColors()
            vc.sidebarTableView.layoutSubviews()
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
        let windowWidth = self.view.frame.width
        let translation = swipe.translation(in: notesTable)

        if swipe.state == .began {
            self.sidebarTableView.isUserInteractionEnabled = true
            self.width = self.notesTable.frame.size.width

            if self.width == windowWidth {
                self.sidebarWidth = 0
            } else {
                self.sidebarWidth = sidebarWidthConstraint.constant
            }

            self.sidebarWidthConstraint.constant = self.maxSidebarWidth
            return
        }

        let sidebarWidth = self.sidebarWidth + translation.x

        if swipe.state == .changed {
            if sidebarWidth > self.maxSidebarWidth {
                return
            } else if sidebarWidth < 0 {
                return
            } else {
                self.noteTableViewLeadingConstraint.constant = sidebarWidth
            }
        }

        if swipe.state == .ended {
            if translation.x > 0 {
                self.noteTableViewLeadingConstraint.constant = self.maxSidebarWidth
            }

            if translation.x < 0 {
                self.noteTableViewLeadingConstraint.constant = 0
            }

            UIView.animate(withDuration: 0.15, animations: {
                if translation.x > 0 {
                    self.view.layoutIfNeeded()
                }

                if translation.x < 0 {
                    self.view.layoutIfNeeded()
                }
            }) { _ in
                if translation.x > 0 {
                    UserDefaultsManagement.sidebarSize = self.maxSidebarWidth
                    self.noteTableViewLeadingConstraint.constant = self.maxSidebarWidth
                    self.sidebarWidthConstraint.constant = self.maxSidebarWidth
                    self.sidebarTableView.isUserInteractionEnabled = true
                }

                if translation.x < 0 {
                    UserDefaultsManagement.sidebarSize = 0
                    self.noteTableViewLeadingConstraint.constant = 0
                    self.sidebarTableView.isUserInteractionEnabled = false
                    self.sidebarWidthConstraint.constant = 0
                }
            }
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

    public func refreshTextStorage(note: Note) {
        DispatchQueue.main.async {
            guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController,
                let viewController = pageController.orderedViewControllers[1] as? UINavigationController,
                let evc = viewController.viewControllers[0] as? EditorViewController
                else { return }

            evc.fill(note: note)
        }
    }

    private func calculateLabelMaxWidth() -> CGFloat {
        var width = CGFloat(0)

        for i in 0...4 {
            var j = 0

            while let cell = sidebarTableView.cellForRow(at: IndexPath(row: j, section: i)) as? SidebarTableCellView {

                if let font = cell.label.font, let text = cell.label.text {
                    let labelWidth = (text as NSString).size(withAttributes: [.font: font]).width

                    if labelWidth > width {
                        width = labelWidth
                    }
                }

                j += 1
            }

        }

        return width + 40
    }
}
