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
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: SLComposeServiceViewController {

    // MARK: - Properties

    private var hasImages = false
    private var urlPreview: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
    }

    // MARK: - Configuration

    private func configureNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar,
              let rightButton = navigationBar.topItem?.rightBarButtonItem else {
            return
        }

        rightButton.title = NSLocalizedString("New note", comment: "")
        navigationBar.tintColor = .mainTheme

        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 20))
        titleLabel.text = "FSNotes"
        titleLabel.font = UserDefaultsManagement.noteFont.bold().withSize(18)
        navigationBar.topItem?.titleView = titleLabel
    }

    // MARK: - Preview

    override func loadPreviewView() -> UIView! {
        urlPreview = textView.text

        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return UIView()
        }

        processInputItems(inputItems)
        return hasImages ? super.loadPreviewView() : UIView()
    }

    private func processInputItems(_ items: [NSExtensionItem]) {
        for item in items {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                if checkForImages(in: attachment) {
                    hasImages = true
                    textView.text = ""
                    return
                }

                loadURLIfNeeded(from: attachment)
            }
        }
    }

    private func checkForImages(in attachment: NSItemProvider) -> Bool {
        return attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) ||
               attachment.hasItemConformingToTypeIdentifier(kUTTypeJPEG as String)
    }

    private func loadURLIfNeeded(from attachment: NSItemProvider) {
        guard attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) else {
            return
        }

        attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { [weak self] url, error in
            guard let self = self,
                  let url = url as? URL,
                  error == nil else {
                return
            }

            self.handleLoadedURL(url)
        }
    }

    private func handleLoadedURL(_ url: URL) {
        if url.absoluteString.starts(with: "file:///") {
            loadFileContent(from: url)
        } else {
            updateTextViewWithURL(url)
        }
    }

    private func loadFileContent(from url: URL) {
        guard let fileData = try? Data(contentsOf: url),
              let text = String(data: fileData, encoding: .utf8) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.textView.text = text
        }
    }

    private func updateTextViewWithURL(_ url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let preview = self.urlPreview ?? ""
            self.textView.text = "\(preview)\n\n\(url.absoluteString)".trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Validation & Post

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        saveNote()
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    // MARK: - Save Note

    private func saveNote() {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            closeExtension()
            return
        }

        let note = createNote()
        appendTextContent(to: note)
        processAttachments(from: inputItems, note: note)
    }

    private func createNote() -> Note {
        let note = Note()
        Storage.shared().add(note)

        var urls = UserDefaultsManagement.importURLs
        urls.insert(note.url, at: 0)
        UserDefaultsManagement.importURLs = urls

        return note
    }

    private func appendTextContent(to note: Note) {
        guard !textView.text.isEmpty else { return }
        note.append(string: NSMutableAttributedString(string: textView.text))
    }

    private func processAttachments(from items: [NSExtensionItem], note: Note) {
        var imageProviders: [NSItemProvider] = []

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    imageProviders.append(provider)
                } else if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    processURLAttachment(note: note)
                    return
                } else if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                    processTextAttachment(note: note)
                    return
                }
            }
        }

        if imageProviders.isEmpty {
            closeExtension()
        } else {
            processImageAttachments(imageProviders, note: note)
        }
    }

    private func processImageAttachments(_ providers: [NSItemProvider], note: Note) {
        let totalCount = providers.count
        var processedCount = 0

        for provider in providers {
            provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: [:]) { [weak self] data, error in
                guard let self = self, error == nil else {
                    processedCount += 1
                    if processedCount == totalCount {
                        self?.finalizeNoteSave(note)
                    }
                    return
                }

                let imageData = self.extractImageData(from: data)
                let url = data as? URL

                if let imageData = imageData {
                    note.append(image: imageData, url: url)
                }

                processedCount += 1
                if processedCount == totalCount {
                    self.finalizeNoteSave(note)
                }
            }
        }
    }

    private func extractImageData(from data: Any?) -> Data? {
        if let data = data as? Data {
            return data
        } else if let image = data as? UIImage {
            return image.jpegData(compressionQuality: 1)
        } else if let url = data as? URL {
            return try? Data(contentsOf: url)
        }
        return nil
    }

    private func processURLAttachment(note: Note) {
        guard !hasImages, let contentText = contentText else {
            closeExtension()
            return
        }

        if let url = URL(string: contentText),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data),
           image.size.width > 0 {
            note.append(image: data)
        } else {
            appendContentWithPrefix(contentText, to: note)
        }

        finalizeNoteSave(note)
    }

    private func processTextAttachment(note: Note) {
        guard !hasImages, let contentText = contentText else {
            closeExtension()
            return
        }

        appendContentWithPrefix(contentText, to: note)
        finalizeNoteSave(note)
    }

    private func appendContentWithPrefix(_ content: String, to note: Note) {
        let prefix = note.content.length == 0 ? "" : "\n\n"
        let string = NSMutableAttributedString(string: "\(prefix)\(content)")
        note.append(string: string)
    }

    private func finalizeNoteSave(_ note: Note) {
        if note.saveSimple() {
            Storage.shared().add(note)
        }
        closeExtension()
    }

    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: extensionContext?.inputItems, completionHandler: nil)
    }
}
