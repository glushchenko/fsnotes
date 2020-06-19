//
//  ShareViewController.swift
//  FSNotes iOS Share
//
//  Created by Oleksandr Glushchenko on 3/18/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import MobileCoreServices
import Social
import NightNight
import Kanna

@objc(ShareViewController)

class ShareViewController: SLComposeServiceViewController {
    private var notes: [Note]?
    private var projects: [Project]?
    private var imagesFound = false
    private var urlPreview: String?
    private var instagram: Data?
    
    public var currentProject: Project?
    public let projectItem = SLComposeSheetConfigurationItem()
    public let appendItem = SLComposeSheetConfigurationItem()

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13.0, *) {
            _ = NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { (_) in
                if let layoutContainerView = self.view.subviews.last {
                    layoutContainerView.frame.size.height += 45
                }
            }
        }
        
        preferredContentSize = CGSize(width: 300, height: 300)
        navigationController!.navigationBar.topItem!.rightBarButtonItem!.title = NSLocalizedString("New note", comment: "")
        navigationController?.navigationBar.backgroundColor = Colors.Header.normalResource
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 20))
        let font = UserDefaultsManagement.noteFont.italic().bold().withSize(16)
        label.text = "FSNotes"
        label.font = font
        label.textColor = UIColor.white
        navigationController?.navigationBar.topItem?.titleView = label
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        textView.setContentOffset(.zero, animated: true)

        if let table = textView.superview?.superview?.superview as? UITableView {
            let length = table.numberOfRows(inSection: 0)
            table.scrollToRow(at: IndexPath(row: length - 1, section: 0), at: .bottom, animated: true)

            for item in 0...2 {
                if let cell = table.cellForRow(at: IndexPath(item: item, section: 0)) {
                    cell.textLabel?.textColor = UIColor(red:0.19, green:0.38, blue:0.57, alpha:1.0)
                }
            }
        }

        if let font = self.textView.font, #available(iOSApplicationExtension 11.0, *) {
            let fontMetrics = UIFontMetrics(forTextStyle: .largeTitle)
            self.textView.font = fontMetrics.scaledFont(for: font).italic()
            self.textView.textColor = UIColor.darkGray
        }
    }

    override func loadPreviewView() -> UIView! {
        urlPreview = self.textView.text

        if let context = self.extensionContext,
            let input = context.inputItems as? [NSExtensionItem] {
            for row in input {
                if let attach = row.attachments {
                    for attachRow in attach {
                        if attachRow.hasItemConformingToTypeIdentifier(kUTTypeImage as String) || attachRow.hasItemConformingToTypeIdentifier(kUTTypeJPEG as String){
                            imagesFound = true

                            textView.text = ""
                            return super.loadPreviewView()
                        }

                        if attachRow.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                            attachRow.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (url, error) in
                                if let data = url as? NSURL, let textLink = data.absoluteString {
                                    self.checkInstagram(data: data)

                                    DispatchQueue.main.async {
                                        let preview = self.urlPreview ?? String()
                                        self.textView.text = "\(preview)\n\n\(textLink)".trimmingCharacters(in: .whitespacesAndNewlines)

                                    }
                                }
                            })
                        }
                    }
                }
            }
        }

        return UIView()
    }

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        save()
    }

    override func configurationItems() -> [Any]! {
        let storage = Storage.sharedInstance()
        var urls = [URL]()

        if let inbox = UserDefaultsManagement.storageUrl {
            urls.append(inbox)
        }

        if let archive = UserDefaultsManagement.archiveDirectory {
            urls.append(archive)
        }

        urls.append(contentsOf: UserDefaultsManagement.projects)
        storage.loadProjects(from: urls)

        projectItem?.title = NSLocalizedString("Project", comment: "")
        projectItem?.tapHandler = {
            let controller = ProjectListController()
            controller.delegate = self

            let projects = storage.getProjects()
            controller.setProjects(projects: projects)

            self.pushConfigurationViewController(controller)
        }

        appendItem?.title = NSLocalizedString("Append to", comment: "")

        DispatchQueue.global().async {
            if let projectURL = UserDefaultsManagement.lastSelectedURL,
                let project = storage.getProjectBy(url: projectURL)
            {
                self.currentProject = project
                self.loadNotesFrom(project: project)
            }

            DispatchQueue.main.async {
                self.projectItem?.value = self.currentProject?.label
            }

            if let note = self.notes?.first {
                note.load()
                note.loadPreviewInfo()

                DispatchQueue.main.async {
                    self.appendItem?.value = note.getName()
                    self.appendItem?.tapHandler = {
                        self.save(note: note)
                    }
                }
            }
        }

        guard let select = SLComposeSheetConfigurationItem() else { return [] }
        select.title = NSLocalizedString("Choose for append", comment: "")
        select.tapHandler = {
            if let notes = self.notes {
                let controller = NotesListController()
                controller.delegate = self
                controller.setNotes(notes: notes)
                self.pushConfigurationViewController(controller)
            }
        }

        return [self.projectItem!, self.appendItem!, select]
    }

    public func save(note: Note? = nil) {
        guard let context = self.extensionContext,
            let input = context.inputItems as? [NSExtensionItem] else { return }

        let note = note ?? Note(project: self.currentProject)
        Storage.sharedInstance().add(note)

        var started = 0
        var finished = 0

        var urls = UserDefaultsManagement.importURLs
        urls.insert(note.url, at: 0)
        UserDefaultsManagement.importURLs = urls

        if let instagram = self.instagram {
            note.append(image: instagram)
            note.append(string: NSMutableAttributedString(string: "\n\n" + self.textView.text))
            note.write()
            self.close()
            return
        }

        for item in input {
            if let a = item.attachments {
                for provider in a {
                    if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                        started = started + 1
                        provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil, completionHandler: { (data, error) in

                            var imageData = data as? Data

                            if let image = data as? UIImage {
                                imageData = image.jpegData(compressionQuality: 1)
                            } else if let url = data as? URL {
                                imageData = try? Data.init(contentsOf: url)
                            }

                            let url = data as? URL
                            if let data = imageData {
                                note.append(image: data, url: url)
                            }

                            finished = finished + 1
                            if started == finished {
                                if self.textView.text.count > 0 {
                                    note.append(string: NSMutableAttributedString(string: "\n\n" + self.textView.text))
                                }
                                
                                note.write()
                                self.close()
                                return
                            }
                        })
                    } else if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) || provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {

                        if !imagesFound, let contentText = self.contentText {
                            let prefix = self.getPrefix(for: note)
                            let string = NSMutableAttributedString(string: "\(prefix)\(contentText)")
                            note.append(string: string)
                            note.write()
                            self.close()
                            return
                        }
                    }
                }
            }
        }
    }

    public func close() {
        if let context = self.extensionContext {
            context.completeRequest(returningItems: context.inputItems, completionHandler: nil)
        }
    }

    private func getPrefix(for note: Note) -> String {
        if note.content.length == 0 {
            return String()
        }

        return "\n\n"
    }

    public func loadNotesFrom(project: Project) {
        let storage = Storage.sharedInstance()

        if storage.getNotesBy(project: project).count == 0 {
            storage.loadLabel(project)
        }

        let notes = storage.noteList.filter({$0.project == project })
        self.notes = storage.sortNotes(noteList: notes, filter: "")

        if let notes = self.notes {
            DispatchQueue.main.async {
                if let note = notes.first {
                    note.load()
                    note.loadPreviewInfo()
                    self.appendItem?.value = note.title
                }
            }
        }
    }

    private func checkInstagram(data: NSURL) {
        if let path = data.absoluteString, path.starts(with: "https://www.instagram.com") {
            let html = try? String(contentsOf: data as URL)

            if let doc = try? Kanna.HTML(html: html!, encoding: String.Encoding.utf8) {
                if let metaSet = doc.head?.css("meta") {
                    for meta in metaSet {
                        if let property = meta["property"]?.lowercased {
                            if property().hasPrefix("og:image"), let imagePath = meta["content"] {

                                if let imURL = URL(string: imagePath), let instaData = try? Data(contentsOf: imURL) {
                                    self.instagram = instaData

                                    DispatchQueue.main.async {
                                        self.textView.text = imURL.path
                                    }
                                }

                                break
                            }
                        }
                    }
                }
            }
        }
    }
}
