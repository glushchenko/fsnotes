//
//  DayOneImportHelper.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import SSZipArchive

class DayOneImportHelper {

    private var url: URL
    public var storage: Storage

    init(url: URL, storage: Storage) {
        self.url = url
        self.storage = storage
    }

    public func check() -> Project? {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let unarchivedURL = tmp.appendingPathComponent(url.deletingPathExtension().lastPathComponent)

        var isDirectory = ObjCBool(true)
        if FileManager.default.fileExists(atPath: unarchivedURL.path, isDirectory: &isDirectory) {
            try? FileManager.default.removeItem(atPath: unarchivedURL.path)
        }

        try? FileManager.default.createDirectory(at: unarchivedURL, withIntermediateDirectories: true, attributes: nil)

        SSZipArchive.unzipFile(atPath: url.path, toDestination: unarchivedURL.path)

        return parse(unarchivedURL: unarchivedURL)
    }

    private func parse(unarchivedURL: URL) -> Project? {
        let journalURL = unarchivedURL.appendingPathComponent("Journal.json")
        let photosURL = unarchivedURL.appendingPathComponent("photos")

        guard let json = try? String(contentsOf: journalURL) else { return nil }

        do {
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            decoder.dateDecodingStrategy = .formatted(formatter)

            let entries = try decoder.decode(Entries.self, from: json.data(using: .utf8)!)

            guard entries.entries.count > 0, let project = createDiaryProject() else { return nil }

            for entry in entries.entries {
                let note = Note(name: String(Date().toMillis()), project: project)

                guard let content = entry.text, content.trim().count > 0 else { continue }

                let imagesWrapper = getImagesWrapper(entry: entry, note: note, photosSrcURL: photosURL)

                let wrapper = note.getFileWrapper(with: imagesWrapper)
                note.write(with: entry.creationDate, from: wrapper)

                storage.add(note)
            }

            return project
        } catch {
            print(error)
        }

        return nil
    }

    private func getImagesWrapper(entry: Entry, note: Note, photosSrcURL: URL) -> FileWrapper? {

        let iWrapper = FileWrapper.init(directoryWithFileWrappers: [:])
        iWrapper.preferredFilename = "assets"

        guard var content = entry.text?.replacingOccurrences(of: "\\/", with: "/") else { return nil }

        if let tags = entry.tags {
            let hashTags = tags.map({ return ("@" + $0) })
            content += "\n\n\(hashTags.joined(separator: ", "))"
        }

        if let photos = entry.photos {
            for photo in photos {
                let mdPath = note.getMdImagePath(name: "\(photo.md5).jpeg")
                content = content.replacingOccurrences(of: "dayone-moment://\(photo.identifier)", with: mdPath)
                let imageSource = photosSrcURL.appendingPathComponent("\(photo.md5).jpeg")

                if note.isTextBundle(), let data = try? Data(contentsOf: imageSource) {
                    iWrapper.addRegularFile(withContents: data, preferredFilename: "\(photo.md5).jpeg")
                } else if let imageDestination = note.getImageUrl(imageName: mdPath) {
                    try? FileManager.default.copyItem(at: imageSource, to: imageDestination)
                }
            }
        }

        note.content = NSMutableAttributedString(string: content)
        note.creationDate = entry.creationDate

        return iWrapper
    }

    private func createDiaryProject() -> Project? {
        guard let rootProject = storage.getRootProject() else { return nil }

        let project = storage.createProject(name: "Diary")
        project.parent = rootProject
        project.sortBy = .creationDate
        project.firstLineAsTitle = true
        project.saveSettings()

        return project
    }
}

struct Entries: Decodable {
    let entries: [Entry]
}

struct Photo: Decodable {
    let md5: String
    let identifier: String
}

struct Entry: Decodable {
    let text: String?
    let photos: [Photo]?
    let creationDate: Date
    let tags: [String]?
}
