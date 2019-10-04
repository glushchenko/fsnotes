//
//  NSMutableAttributedString+Attachments.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 10/3/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension NSMutableAttributedString {
    func loadImages(note: Note) {
        let paragraphRange = NSRange(0..<length)
        var offset = 0

        NotesTextProcessor.imageInlineRegex.matches(string, range: paragraphRange) { (result) -> Void in
            guard var range = result?.range else { return }

            range = NSRange(location: range.location - offset, length: range.length)
            let mdLink = self.attributedSubstring(from: range).string

            var path = String()
            var title = String()

            if let titleRange = result?.range(at: 2) {
                title = self.mutableString.substring(with: NSRange(location: titleRange.location - offset, length: titleRange.length))
            }

            if let linkRange = result?.range(at: 3) {
                path = self.mutableString.substring(with: NSRange(location: linkRange.location - offset, length: linkRange.length))
            }

            guard let imageURL = note.getImageUrl(imageName: path) else { return }

            let cacheUrl = note.project.url.appendingPathComponent("/.cache/")
            let imageAttachment = ImageAttachment(title: title, path: path, url: imageURL, cache: cacheUrl, note: note)

            if let attributedStringWithImage = imageAttachment.getAttributedString() {
                offset += mdLink.count - 1
                self.replaceCharacters(in: range, with: attributedStringWithImage)
            }
        }
    }

    func getLocalNotePath(path: String, innerRange: NSRange, note: Note) -> String? {
        let noteStorage = note.project
        var notePath: String
        let storagePath = noteStorage.url.path

        if path.starts(with: "/i/") {
            //let path = getFilePath(innerRange: innerRange)
            let path = ""
            return note.project.url.path + path
        }

        if path.starts(with: "http://") || path.starts(with: "https://"), let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            notePath = storagePath + "/i/" + encodedPath
            return notePath
        }

        if note.isTextBundle() {
            if let name = path.removingPercentEncoding {
                return "\(note.getURL().path)/\(name)"
            }
        }

        //let path = getFilePath(innerRange: innerRange)
        let path = ""
        notePath = storagePath + "/" + path

        return notePath
    }
}
