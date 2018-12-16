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

    @IBOutlet weak var preHeaderView: UIView!
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

    public var indicator: UIActivityIndicatorView?

    public var storage: Storage?
    public var cloudDriveManager: CloudDriveManager?

    private let searchQueue = OperationQueue()
    private var delayedInsert: Note?

    private var filteredNoteList: [Note]?
    private var maxSidebarWidth = CGFloat(0)

    public var is3DTouchShortcut = false
    private var isActiveTableUpdating = false

    override func viewDidLoad() {
        self.searchButton.setImage(UIImage(named: "search_white"), for: .normal)
        self.settingsButton.setImage(UIImage(named: "more_white"), for: .normal)

        self.preHeaderView.mixedBackgroundColor = Colors.Header
        self.headerView.mixedBackgroundColor = Colors.Header
        self.searchView.mixedBackgroundColor = Colors.Header

        self.search.mixedBackgroundColor = Colors.Header
        self.search.mixedBarTintColor = Colors.Header

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
        notesTable.dataSource = notesTable
        notesTable.delegate = notesTable
        notesTable.layer.zPosition = 100
        notesTable.rowHeight = UITableViewAutomaticDimension
        notesTable.estimatedRowHeight = 160

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(togglseSearch), for: .valueChanged)

        notesTable.refreshControl = refreshControl

        sidebarTableView.dataSource = sidebarTableView
        sidebarTableView.delegate = sidebarTableView
        sidebarTableView.viewController = self

        self.sidebarTableView.isUserInteractionEnabled = (UserDefaultsManagement.sidebarSize > 0)

        UserDefaultsManagement.fontSize = 17
        self.storage = Storage.sharedInstance()

        guard let storage = self.storage else { return }

        if storage.noteList.count == 0 {
            DispatchQueue.global().async {
                print("CloudDrive sync started")
                storage.initiateCloudDriveSync()
            }

            storage.loadDocuments() {
                DispatchQueue.main.async {
                    self.reloadSidebar()
                }
            }

            self.indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
            self.configureIndicator(indicator: self.indicator!, view: self.view)

            DispatchQueue.main.async {
                self.initTableData()
            }
        }

        self.sidebarTableView.sidebar = Sidebar()
        self.sidebarTableView.reloadData()
        self.maxSidebarWidth = self.calculateLabelMaxWidth()

        guard let pageController = self.parent as? PageViewController else {
            return
        }

        pageController.disableSwipe()

        keyValueWatcher()

        NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeChanged), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)

        NotificationCenter.default.addObserver(self, selector:#selector(viewWillAppear(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

        let swipe = UIPanGestureRecognizer(target: self, action: #selector(handleSidebarSwipe))
        swipe.minimumNumberOfTouches = 1
        swipe.delegate = self

        view.addGestureRecognizer(swipe)
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(didChangeScreenBrightness), name: NSNotification.Name.UIScreenBrightnessDidChange, object: nil)
    }

    public func reloadSidebar(select project: Project? = nil) {
        DispatchQueue.main.async {
            self.sidebarTableView.sidebar = Sidebar()
            self.maxSidebarWidth = self.calculateLabelMaxWidth()
            self.sidebarTableView.reloadData()

            guard let items = self.sidebarTableView.sidebar?.items[1], let selected = project, let i = items.lastIndex(where: { $0.project == selected }) else { return }

            let indexPath = IndexPath(row: i, section: 1)
            self.sidebarTableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            self.sidebarTableView.tableView(self.sidebarTableView, didSelectRowAt: indexPath)
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = gestureRecognizer as? UIPanGestureRecognizer {
            if recognizer.translation(in: self.view).x > 0 || sidebarTableView.frame.width != 0 {
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
                self.notesTable.actionsSheet(notes: notes)
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


    func keyValueWatcher() {
        let keyStore = NSUbiquitousKeyValueStore()
        keyStore.synchronize()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ubiquitousKeyValueStoreDidChange),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: keyStore)
    }

    @objc func ubiquitousKeyValueStoreDidChange(notification: NSNotification) {
        if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            for key in keys {
                if key == "co.fluder.fsnotes.pins.shared" {
                    _ = storage?.restoreCloudPins()
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

    public func configureIndicator(indicator: UIActivityIndicatorView, view: UIView) {
        indicator.frame = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
        indicator.center = view.center
        indicator.layer.cornerRadius = 5
        indicator.layer.borderWidth = 1
        indicator.layer.borderColor = UIColor.lightGray.cgColor
        indicator.mixedBackgroundColor = MixedColor(normal: 0xb7b7b7, night: 0x47444e)
        view.addSubview(indicator)
        indicator.bringSubview(toFront: view)
        startAnimation(indicator: indicator)
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

    public func initTableData() {
        guard let storage = self.storage else { return }

        self.updateTable() {
            self.stopAnimation(indicator: self.indicator)
            self.cloudDriveManager = CloudDriveManager(delegate: self, storage: storage)

            if !self.is3DTouchShortcut, let note = Storage.sharedInstance().noteList.first {

                DispatchQueue.main.async {
                    let evc = UIApplication.getEVC()
                    if evc.note == nil {
                        evc.fill(note: note)
                    }
                }
            }
        }
    }

    private var accessTime = DispatchTime.now()

    public func updateTable(search: Bool = false, completion: @escaping () -> Void) {
        self.isActiveTableUpdating = true
        self.searchQueue.cancelAllOperations()

        self.notesTable.notes.removeAll()
        self.notesTable.reloadData()

        guard let storage = self.storage else { return }
        self.startAnimation(indicator: self.indicator)

        let filter = self.search.text!
        var terms = filter.split(separator: " ")
        let sidebarItem = self.sidebarTableView.getSidebarItem()
        let type: SidebarItemType = sidebarItem?.type ?? .All

        if type == .Todo {
            terms.append("- [ ]")
        }

        self.searchQueue.cancelAllOperations()

        let operation = BlockOperation()
        operation.addExecutionBlock {

            self.accessTime = DispatchTime.now()

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
                    self.notesTable.notes = storage.sortNotes(noteList: notes, filter: "", project: sidebarItem?.project)
                }
            } else {
                self.notesTable.notes.removeAll()
            }

            if operation.isCancelled {
                completion()
                return
            }

            let delayInSeconds = 0.3
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delayInSeconds) {

                if DispatchTime.now() - delayInSeconds < self.accessTime {
                    return
                }

                self.notesTable.reloadData()

                if let note = self.delayedInsert {
                    self.notesTable.insertRow(note: note)
                    self.delayedInsert = nil
                }

                self.isActiveTableUpdating = false
                completion()
                self.stopAnimation(indicator: self.indicator)
            }
        }

        self.searchQueue.addOperation(operation)
    }

    public func isFit(note: Note, sidebarItem: SidebarItem? = nil) -> Bool {
        let type: SidebarItemType = sidebarItem?.type ?? .All
        var project: Project? = nil
        var sidebarName = ""

        if let sidebarItem = sidebarItem {
            sidebarName = sidebarItem.name
            project = sidebarItem.project
        }

        if type == .Trash && note.isTrash()
            || type == .All && note.project.showInCommon
            || type == .Tag && note.tagNames.contains(sidebarName)
            || [.Category, .Label].contains(type) && project != nil && note.project == project
            || project != nil && project!.isRoot && note.project.parent == project
            || type == .Archive && note.project.isArchive
            || type == .Todo && !note.project.isArchive {

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

    func createNote(content: String? = nil, pasteboard: Bool? = nil) {
        var currentProject: Project
        var tag: String?

        if let project = self.storage?.getProjects().first {
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

        guard let pageController = UIApplication.shared.windows[0].rootViewController as? PageViewController, let viewController = pageController.orderedViewControllers[1] as? UINavigationController, let evc = viewController.viewControllers[0] as? EditorViewController else {
            return
        }

        pageController.switchToEditor()

        evc.note = note
        evc.fill(note: note)

        if self.isActiveTableUpdating {
            self.delayedInsert = note
        } else {
            self.notesTable.insertRow(note: note)
        }
    }

    public func savePasteboard(note: Note) {
        let pboard = UIPasteboard.general
        let pasteboardString: String? = pboard.string

        if let content = pasteboardString {
            note.content = NSMutableAttributedString(string: content)
        }

        if let image = pboard.image {
            if let data = UIImageJPEGRepresentation(image, 1) {
                guard let fileName = ImagesProcessor.writeImage(data: data, note: note) else { return }
                let imagePath = note.type == .TextBundle ? "assets" : "/i"
                note.content = NSMutableAttributedString(string: "![](\(imagePath)/\(fileName))\n\n")
            }
        }

        note.save()
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

            UserDefaultsManagement.codeTheme = "atom-one-light"
            NotesTextProcessor.hl = nil
            evc.refill()

            if evc.editArea != nil {
                evc.editArea.keyboardAppearance = .default
            }
            
            vc.search.keyboardAppearance = .default

            vc.sidebarTableView.sidebar = Sidebar()
            vc.sidebarTableView.reloadData()
            vc.notesTable.reloadData()

            if vc.search.isFirstResponder {
                vc.search.endEditing(true)
                vc.search.becomeFirstResponder()
            }

            return
        }

        if (UserDefaultsManagement.maxNightModeBrightnessLevel > brightness && NightNight.theme == .normal) {
            NightNight.theme = .night

            UserDefaultsManagement.codeTheme = "monokai-sublime"
            NotesTextProcessor.hl = nil
            evc.refill()

            if evc.editArea != nil {
                evc.editArea.keyboardAppearance = .dark
            }
            
            vc.search.keyboardAppearance = .dark

            vc.sidebarTableView.sidebar = Sidebar()
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
            if sidebarWidth > self.maxSidebarWidth || sidebarWidth < 0 {
                return
            } else {
                self.noteTableViewLeadingConstraint.constant = sidebarWidth

                UIView.animate(withDuration: 0.15) { [weak self] in
                    self?.view.layoutIfNeeded()
                }
            }
            return
        }

        if swipe.state == .ended {
            if translation.x > 0 {
                self.noteTableViewLeadingConstraint.constant = self.maxSidebarWidth
            }

            if translation.x < 0 {
                self.noteTableViewLeadingConstraint.constant = 0
            }

            UIView.animate(withDuration: 0.2, delay: 0.0, options: .beginFromCurrentState, animations: {
                if translation.x > 0 || translation.x < 0 {
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

            note.isCached = false
            evc.fill(note: note)
        }
    }

    private func calculateLabelMaxWidth() -> CGFloat {
        var width = CGFloat(85)

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
