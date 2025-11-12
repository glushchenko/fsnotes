//
//  NSTextAttachment+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 10/2/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import AppKit

extension NSTextAttachment {
    convenience init(url: URL, path: String, title: String) {
        let meta = Attachment(url: url, title: title, path: path)

        if let encoded = try? JSONEncoder().encode(meta) {
            let fileWrapper = FileWrapper(regularFileWithContents: encoded)
            fileWrapper.preferredFilename = "attachment.bin"
            self.init(fileWrapper: fileWrapper)
        } else {
            self.init()
        }
    }

    public func isFile() -> Bool {
        #if os(iOS)
            return false
        #endif

        #if os(OSX)
            return (attachmentCell?.cellSize().height == 30)
        #endif
    }

    public func getMeta() -> Attachment? {
        if let data = fileWrapper?.regularFileContents,
           let meta = try? JSONDecoder().decode(Attachment.self, from: data) {
            return meta
        }

        return nil
    }

    public func saveMetaData(data: Data, preferredName: String? = nil, title: String? = nil) {
        var meta = Attachment(data: data, preferredName: preferredName, title: title)

        meta.url = URL(fileURLWithPath: "this_path_is_not_exist")
        guard let encoded = try? JSONEncoder().encode(meta) else { return }

        let fileWrapper = FileWrapper(regularFileWithContents: encoded)
        fileWrapper.preferredFilename = "attachment.bin"

        self.fileWrapper = fileWrapper
    }

    public func saveMetaData(url: URL? = nil, path: String? = nil, title: String? = nil) {
        guard var meta = getMeta() else { return }
        meta.data = nil

        if let url = url {
            meta.url = url
        }

        if let path = path {
            meta.path = path
        }

        if let title = title {
            meta.title = title
        }

        guard let encoded = try? JSONEncoder().encode(meta) else { return }

        let fileWrapper = FileWrapper(regularFileWithContents: encoded)
        fileWrapper.preferredFilename = "attachment.bin"

        self.fileWrapper = fileWrapper
    }

    public func configure(attachment: Attachment) {
        guard let encoded = try? JSONEncoder().encode(attachment) else { return }

        let fileWrapper = FileWrapper(regularFileWithContents: encoded)
        fileWrapper.preferredFilename = "attachment.bin"

        self.fileWrapper = fileWrapper
    }
}
