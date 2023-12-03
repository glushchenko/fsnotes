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
        
        preferredContentSize = CGSize(width: 300, height: 300)
        navigationController!.navigationBar.topItem!.rightBarButtonItem!.title = NSLocalizedString("New note", comment: "")
        navigationController!.navigationBar.tintColor = UIColor.mainTheme

        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 20))
        let font = UserDefaultsManagement.noteFont.italic().bold().withSize(18)
        label.text = "FSNotes"
        label.font = font
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
                    //cell.textLabel?.textColor = UIColor(red:0.19, green:0.38, blue:0.57, alpha:1.0)
                    if let fontSize = cell.textLabel?.font.pointSize {
                        //cell.textLabel?.font = UIFont.boldSystemFont(ofSize: fontSize)
                    }
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
                                guard let url = url as? URL else { return }

                                guard !url.absoluteString.startsWith(string: "file:///") else {
                                    if let fileContent = try? Data(contentsOf: url), let text = String(data: fileContent, encoding: String.Encoding.utf8) {
                                        DispatchQueue.main.async {
                                            self.textView.text = text
                                        }
                                    }
                                    return
                                }

                                DispatchQueue.main.async {
                                    let preview = self.urlPreview ?? String()
                                    self.textView.text = "\(preview)\n\n\(url.absoluteString)".trimmingCharacters(in: .whitespacesAndNewlines)

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
        let storage = Storage.shared()
        var urls = [URL]()

        if let inbox = UserDefaultsManagement.storageUrl {
            urls.append(inbox)
        }

        storage.loadProjects(from: urls)

        projectItem?.title = NSLocalizedString("Project", comment: "")
        projectItem?.tapHandler = {
            let controller = ProjectListController()
            controller.delegate = self

            let projects = storage.getProjects()
            controller.setProjects(projects: projects)

            self.pushConfigurationViewController(controller)
        }

        return [self.projectItem!]
    }

    public func save(note: Note? = nil) {
        guard let context = self.extensionContext,
            let input = context.inputItems as? [NSExtensionItem] else { return }

        let note = note ?? Note(project: self.currentProject)
        Storage.shared().add(note)

        var started = 0
        var finished = 0

        var urls = UserDefaultsManagement.importURLs
        urls.insert(note.url, at: 0)
        UserDefaultsManagement.importURLs = urls

        if let instagram = self.instagram {
            note.append(image: instagram)
            note.append(string: NSMutableAttributedString(string: "\n\n" + self.textView.text))
            note.save()
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
                                
                                note.save()
                                self.close()
                                return
                            }
                        })
                    } else if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                        if !imagesFound, let contentText = self.contentText {

                            guard let url = URL(string: contentText) else {
                                // File URL provided, but text is loaded in textView
                                note.append(string: NSMutableAttributedString(string: contentText))
                                note.save()
                                self.close()
                                return
                            }

                            let data = try? Data(contentsOf: url)

                            if let data = data, let image = UIImage(data: data), image.size.width > 0 {
                                note.append(image: data)
                            } else {
                                let prefix = self.getPrefix(for: note)
                                let string = NSMutableAttributedString(string: "\(prefix)\(contentText)")
                                note.append(string: string)
                            }

                            note.save()
                            self.close()
                            return
                        }

                    } else if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                        if !imagesFound, let contentText = self.contentText {
                            let prefix = self.getPrefix(for: note)
                            let string = NSMutableAttributedString(string: "\(prefix)\(contentText)")
                            note.append(string: string)
                            note.save()
                            self.close()
                            return
                        }
                    }
                }
            }
        }

        self.close()
    }

//    private func checkImage() -> UIImage {
//        attachRow.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (url, error) in
//
//        })
//    }

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
}
