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

    override func viewDidLoad() {
        preferredContentSize = CGSize(width: 300, height: 300)
        navigationController!.navigationBar.topItem!.rightBarButtonItem!.title = "New note"
        navigationController?.navigationBar.backgroundColor = Colors.Header.normalResource
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]


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
    }

    override func loadPreviewView() -> UIView! {
        if let context = self.extensionContext,
            let input = context.inputItems as? [NSExtensionItem] {
            for row in input {
                if let attach = row.attachments as? [NSItemProvider] {
                    for attachRow in attach {
                        if attachRow.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                            return super.loadPreviewView()
                        }

                        if attachRow.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                            attachRow.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (url, error) in
                                if let data = url as? NSURL, let textLink = data.absoluteString {
                                    DispatchQueue.main.async {
                                        self.textView.text = textLink
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
        close()
    }

    override func configurationItems() -> [Any]! {
        guard let append = SLComposeSheetConfigurationItem() else { return [] }
        append.title = "Append to"

        DispatchQueue.global().async {
            let storage = Storage.sharedInstance()
            storage.loadProjects()

            self.notes = storage.sortNotes(noteList: storage.noteList, filter: "")
            if let note = self.notes?.first {
                note.loadContent()

                DispatchQueue.main.async {
                    append.value = note.title
                    append.tapHandler = {
                        self.save(note: note)
                    }
                }
            }
        }

        guard let select = SLComposeSheetConfigurationItem() else { return [] }
        select.title = "Choose for append"
        select.value = "."
        select.tapHandler = {
            if let notes = self.notes {
                let controller = NotesListController()
                controller.delegate = self
                controller.setNotes(notes: notes)
                self.pushConfigurationViewController(controller)
            }
        }

        return [append, select]
    }

    public func save(note: Note? = nil) {
        guard let context = self.extensionContext,
            let input = context.inputItems as? [NSExtensionItem] else { return }

        let note = note ?? Note()

        for item in input {
            if let a = item.attachments as? [NSItemProvider] {
                for provider in a {
                    if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                        provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil, completionHandler: { (data, error) in

                            var imageData = data as? Data
                            if let image = data as? UIImage {
                                imageData = UIImageJPEGRepresentation(image, 1)
                            }

                            if let data = imageData {
                                note.append(image: data)
                            }
                        })

                        close()
                        return

                    } else if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) || provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                        if let contentText = self.contentText {
                            let prefix = self.getPrefix(for: note)
                            let string = NSMutableAttributedString(string: "\(prefix)\(contentText)")
                            note.append(string: string)
                        }
                    }
                }
            }
        }

        self.close()
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
}
