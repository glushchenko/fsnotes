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

@objc(ShareViewController)

class ShareViewController: SLComposeServiceViewController {
    private var notes: [Note]?
    private var projects: [Project]?
    private var imagesFound = false
    private var urlPreview: String?
    
    public var currentProject: Project?
    public let projectItem = SLComposeSheetConfigurationItem()
    public let appendItem = SLComposeSheetConfigurationItem()

    override func viewDidLoad() {
        preferredContentSize = CGSize(width: 300, height: 300)
        navigationController!.navigationBar.topItem!.rightBarButtonItem!.title = "New note"
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
                if let attach = row.attachments as? [NSItemProvider] {
                    for attachRow in attach {
                        if attachRow.hasItemConformingToTypeIdentifier(kUTTypeImage as String) || attachRow.hasItemConformingToTypeIdentifier(kUTTypeJPEG as String){
                            imagesFound = true
                            return super.loadPreviewView()
                        }

                        if attachRow.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                            attachRow.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (url, error) in
                                if let data = url as? NSURL, let textLink = data.absoluteString {
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
        projectItem?.title = "Project"
        projectItem?.tapHandler = {
            if let projects = self.projects {
                let controller = ProjectListController()
                controller.delegate = self
                controller.setProjects(projects: projects)
                self.pushConfigurationViewController(controller)
            }
        }

        appendItem?.title = "Append to"

        DispatchQueue.global().async {
            let storage = Storage.sharedInstance()
            storage.loadProjects(withTrash: false)
            self.projects = storage.getProjects()

            let element = UserDefaultsManagement.lastProject
            if let project = storage.getProjectBy(element: element) {
                self.currentProject = project
                self.loadNotesFrom(project: project)
            }

            DispatchQueue.main.async {
                self.projectItem?.value = self.currentProject?.getFullLabel()
            }

            if let note = self.notes?.first {
                note.load(tags: false)
                note.parseURL()

                DispatchQueue.main.async {
                    self.appendItem?.value = note.getName()
                    self.appendItem?.tapHandler = {
                        self.save(note: note)
                    }
                }
            }
        }

        guard let select = SLComposeSheetConfigurationItem() else { return [] }
        select.title = "Choose for append"
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
        var started = 0
        var finished = 0

        for item in input {
            if let a = item.attachments as? [NSItemProvider] {
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
                                note.append(string: NSMutableAttributedString(string: "\n\n" + self.textView.text))
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
        let notes = storage.noteList.filter({$0.project == project })
        self.notes = storage.sortNotes(noteList: notes, filter: "")

        if let notes = self.notes {
            DispatchQueue.main.async {
                self.appendItem?.value = notes.first?.title
            }
        }
    }
}
