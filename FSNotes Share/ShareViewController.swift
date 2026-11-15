import AppKit
import UniformTypeIdentifiers

final class ShareViewController: NSViewController {
    private let status = NSTextField(wrappingLabelWithString: NSLocalizedString("Save a page, text, images or files to Inbox.", comment: ""))
    private lazy var saveButton = NSButton(title: NSLocalizedString("Save to Inbox", comment: ""),
                                           target: self, action: #selector(save))
    private lazy var cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: ""),
                                             target: self, action: #selector(cancel))
    private let markdownCheckbox = NSButton(checkboxWithTitle: NSLocalizedString("Markdown", comment: ""),
                                            target: nil, action: nil)
    private let contentStack = NSStackView()
    private var saveTask: Task<Void, Never>?

    override func loadView() {
        let title = NSTextField(labelWithString: "FSNotes")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        status.textColor = .secondaryLabelColor
        status.preferredMaxLayoutWidth = 350

        let labels = NSStackView(views: [title, status])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 4

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        let header = NSStackView(views: [icon, labels])
        header.spacing = 12
        header.alignment = .top

        let divider = NSBox()
        divider.boxType = .separator
        markdownCheckbox.state = .on
        markdownCheckbox.toolTip = NSLocalizedString("Turn off to save as plain text.", comment: "")
        saveButton.keyEquivalent = "\r"
        cancelButton.keyEquivalent = "\u{1b}"

        let buttons = NSStackView(views: [cancelButton, saveButton])
        buttons.spacing = 8
        let footer = NSStackView(views: [markdownCheckbox, buttons])
        footer.distribution = .equalSpacing

        let stack = contentStack
        [header, divider, footer].forEach { stack.addArrangedSubview($0) }
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)

        footer.widthAnchor.constraint(equalToConstant: 420).isActive = true
        divider.widthAnchor.constraint(equalTo: footer.widthAnchor).isActive = true

        // Keep the stack independent of the host's transient zero-sized view.
        let content = NSView(frame: NSRect(origin: .zero, size: stack.fittingSize))
        stack.frame = content.bounds
        content.addSubview(stack)
        view = content
        resizeToFitContent()
    }

    private func resizeToFitContent() {
        let fittingSize = contentStack.fittingSize
        let size = NSSize(width: ceil(fittingSize.width), height: ceil(fittingSize.height))
        contentStack.frame = NSRect(origin: .zero, size: size)
        view.setFrameSize(size)
        preferredContentSize = size
    }

    @objc private func save() {
        guard let context = extensionContext else { return }
        let items = context.inputItems.compactMap { $0 as? NSExtensionItem }
        let asMarkdown = markdownCheckbox.state == .on
        saveButton.isEnabled = false
        markdownCheckbox.isEnabled = false
        status.stringValue = NSLocalizedString("Preparing note…", comment: "")
        resizeToFitContent()

        saveTask = Task {
            do {
                let attachments = try await Self.loadAttachments(from: items)
                try Task.checkCancellation()
                if attachments.isEmpty {
                    let clip = try await Self.loadClip(from: items, asMarkdown: asMarkdown)
                    try Task.checkCancellation()
                    try SharedInbox.enqueue(title: clip.title, text: clip.text, asMarkdown: asMarkdown)
                } else {
                    try SharedInbox.enqueue(attachments: attachments)
                }
                context.completeRequest(returningItems: nil)
            } catch is CancellationError {
                return
            } catch {
                status.stringValue = NSLocalizedString("Couldn’t save this item. Check that it’s accessible and try again.", comment: "")
                resizeToFitContent()
                saveButton.isEnabled = true
                markdownCheckbox.isEnabled = true
            }
        }
    }

    @objc private func cancel() {
        saveTask?.cancel()
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }

    private nonisolated static func loadAttachments(from items: [NSExtensionItem]) async throws -> [SharedInbox.Attachment] {
        let providers = items.flatMap { $0.attachments ?? [] }
        var attachments: [SharedInbox.Attachment] = []
        for provider in providers {
            try Task.checkCancellation()
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                let attachment = try await load(provider, type: .fileURL) { item -> SharedInbox.Attachment? in
                    let url: URL?
                    switch item {
                    case let value as URL: url = value
                    case let value as Data: url = URL(dataRepresentation: value, relativeTo: nil)
                    case let value as String: url = URL(string: value)
                    default: url = nil
                    }
                    guard let url, url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
                    let type = UTType(filenameExtension: url.pathExtension)
                    // Keep converting individual HTML and text documents as before.
                    if providers.count == 1, let type, type.conforms(to: .html) || type.conforms(to: .plainText) {
                        return nil
                    }
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return SharedInbox.Attachment(name: url.lastPathComponent, data: try Data(contentsOf: url))
                }
                if let attachment { attachments.append(attachment) }
                continue
            }
            // Ignore alternate text/HTML representations of pages and selections.
            guard let type = provider.registeredTypeIdentifiers.compactMap({ UTType($0) }).first(where: {
                $0.conforms(to: .image) || ($0.conforms(to: .data) && !$0.conforms(to: .text)
                    && !$0.conforms(to: .url) && !$0.conforms(to: .propertyList))
            }) else { continue }
            let suggestedName = provider.suggestedName
            let attachment: SharedInbox.Attachment
            do {
                attachment = try await withCheckedThrowingContinuation { continuation in
                    provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                        guard let url else {
                            continuation.resume(throwing: error ?? CocoaError(.fileReadCorruptFile))
                            return
                        }
                        continuation.resume(with: Result {
                            var name = suggestedName ?? url.lastPathComponent
                            if (name as NSString).pathExtension.isEmpty, let ext = type.preferredFilenameExtension {
                                name += "." + ext
                            }
                            return SharedInbox.Attachment(name: name, data: try Data(contentsOf: url))
                        })
                    }
                }
            } catch {
                var name = suggestedName ?? "Attachment"
                if (name as NSString).pathExtension.isEmpty, let ext = type.preferredFilenameExtension {
                    name += "." + ext
                }
                attachment = SharedInbox.Attachment(name: name, data: try await loadTextData(from: provider, type: type))
            }
            attachments.append(attachment)
        }
        return attachments
    }

    private nonisolated static func loadClip(from items: [NSExtensionItem], asMarkdown: Bool) async throws -> HTMLClip {
        let providers = items.flatMap { $0.attachments ?? [] }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
            if let clip = try? await load(provider, type: .propertyList, transform: { item -> HTMLClip in
                guard let results = (item as? [String: Any])?[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any],
                      let html = results["html"] as? String else { throw CocoaError(.fileReadCorruptFile) }
                return try HTMLClip(data: Data(html.utf8), title: results["title"] as? String,
                                    source: (results["url"] as? String).flatMap { URL(string: $0) },
                                    baseURL: (results["baseURL"] as? String).flatMap { URL(string: $0) },
                                    encoding: "UTF-8", asMarkdown: asMarkdown)
            }) {
                return clip
            }
        }

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.html.identifier) {
            if let clip = try? await load(provider, type: .html, transform: { item in
                switch item {
                case let html as String:
                    return try HTMLClip(data: Data(html.utf8), encoding: "UTF-8", asMarkdown: asMarkdown)
                case let data as Data:
                    return try HTMLClip(data: data, asMarkdown: asMarkdown)
                case let url as URL where url.isFileURL:
                    return try readHTMLFile(url, asMarkdown: asMarkdown)
                default:
                    throw CocoaError(.fileReadCorruptFile)
                }
            }) {
                return clip
            }
        }

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let clip = try? await load(provider, type: .fileURL, transform: { item in
                guard let url = item as? URL, url.isFileURL,
                      let type = UTType(filenameExtension: url.pathExtension) else {
                    throw CocoaError(.fileReadUnsupportedScheme)
                }
                if type.conforms(to: .html) {
                    return try readHTMLFile(url, asMarkdown: asMarkdown)
                }
                guard type.conforms(to: .plainText) else { throw CocoaError(.fileReadUnsupportedScheme) }
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                var encoding = String.Encoding.utf8
                let text = try String(contentsOf: url, usedEncoding: &encoding)
                return try HTMLClip(plainText: text, title: url.deletingPathExtension().lastPathComponent)
            }) {
                return clip
            }
        }

        // Preserve web clipping for URL shares, but use attached text if the URL cannot be clipped.
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }),
           let clip = try? await loadWebPage(from: provider, asMarkdown: asMarkdown) {
            return clip
        }

        let utf16Types: [UTType] = [.utf16PlainText, .utf16ExternalPlainText]
        let plainTextTypes: [UTType] = [.plainText, .utf8PlainText] + utf16Types
        for provider in providers {
            guard let type = provider.registeredTypeIdentifiers.compactMap({ UTType($0) })
                .first(where: { plainTextTypes.contains($0) || $0.conforms(to: .plainText) }) else {
                continue
            }
            let encoding: String.Encoding = utf16Types.contains(type) ? .utf16 : .utf8
            if let data = try? await loadTextData(from: provider, type: type),
               let text = String(data: data, encoding: encoding),
               let clip = try? HTMLClip(plainText: text) {
                return clip
            }
            if let clip = try? await load(provider, type: type, transform: { item in
                switch item {
                case let text as String:
                    return try HTMLClip(plainText: text)
                case let text as NSAttributedString:
                    return try HTMLClip(plainText: text.string)
                case let data as Data:
                    guard let text = String(data: data, encoding: encoding) else {
                        throw CocoaError(.fileReadInapplicableStringEncoding)
                    }
                    return try HTMLClip(plainText: text)
                default:
                    throw CocoaError(.fileReadCorruptFile)
                }
            }) {
                return clip
            }
        }

        for item in items {
            if let text = item.attributedContentText?.string, let clip = try? HTMLClip(plainText: text) {
                return clip
            }
        }
        throw CocoaError(.fileReadCorruptFile)
    }

    private nonisolated static func loadWebPage(from provider: NSItemProvider, asMarkdown: Bool) async throws -> HTMLClip {
        let url = try await load(provider, type: .url) { item in
            guard let url = item as? URL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                throw CocoaError(.fileReadUnsupportedScheme)
            }
            return url
        }

        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let request = URLRequest(url: url, timeoutInterval: 20)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              ["text/html", "application/xhtml+xml"].contains(http.mimeType ?? "") else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try HTMLClip(data: data, source: http.url ?? url, encoding: http.textEncodingName, asMarkdown: asMarkdown)
    }

    private nonisolated static func readHTMLFile(_ url: URL, asMarkdown: Bool) throws -> HTMLClip {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        return try HTMLClip(data: Data(contentsOf: url), title: url.deletingPathExtension().lastPathComponent, asMarkdown: asMarkdown)
    }

    private nonisolated static func loadTextData(from provider: NSItemProvider, type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadCorruptFile))
                }
            }
        }
    }

    private nonisolated static func load<Value>(
        _ provider: NSItemProvider, type: UTType, transform: @escaping (NSSecureCoding) throws -> Value
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, error in
                guard let item else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadCorruptFile))
                    return
                }
                continuation.resume(with: Result { try transform(item) })
            }
        }
    }
}
