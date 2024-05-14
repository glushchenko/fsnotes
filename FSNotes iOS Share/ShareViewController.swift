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

@objc(ShareViewController)

class ShareViewController: SLComposeServiceViewController {

    private var imagesFound = false
    private var urlPreview: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController!.navigationBar.topItem!.rightBarButtonItem!.title = NSLocalizedString("New note", comment: "")
        navigationController!.navigationBar.tintColor = UIColor.mainTheme

        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 20))
        let font = UserDefaultsManagement.noteFont.bold().withSize(18)
        label.text = "FSNotes"
        label.font = font
        navigationController?.navigationBar.topItem?.titleView = label
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
        return []
    }

    public func save() {
        guard let context = self.extensionContext,
            let input = context.inputItems as? [NSExtensionItem] else { return }

        let note = Note()
        Storage.shared().add(note)

        var started = 0
        var finished = 0

        var urls = UserDefaultsManagement.importURLs
        urls.insert(note.url, at: 0)
        UserDefaultsManagement.importURLs = urls

        for item in input {
            if let a = item.attachments {
                for provider in a {
                    if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                        started = started + 1

                        provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: [:], completionHandler: { (data, error) in

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
