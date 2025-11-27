//
//  EditTextView+DragOperation.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.10.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

extension EditTextView
{
    public func handleAttributedText(_ pasteboard: NSPasteboard, note: Note, storage: NSTextStorage, replacementRange: NSRange) -> Bool {

        let locationDiff = selectedRange().location > replacementRange.location
            ? replacementRange.location
            : replacementRange.location - selectedRange().length

        let insertRange = NSRange(location: locationDiff, length: 0)
        let removeRange = selectedRange()

        // drag
        insertText("", replacementRange: removeRange)

        guard let data = pasteboard.data(forType: NSPasteboard.attributed),
              let attributedString = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSAttributedString else { return false }

        // drop
        insertText(attributedString, replacementRange: insertRange)

        // select
        let selectedRange = NSRange(location: locationDiff, length: attributedString.length)
        setSelectedRange(selectedRange)

        return true
    }

    public func handleNoteReference(_ pasteboard: NSPasteboard, note: Note, replacementRange: NSRange) -> Bool {
        guard
            let archivedData = pasteboard.data(forType: NSPasteboard.note),
            let urls = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: archivedData) as? [URL],
            let url = urls.first,
            let draggableNote = Storage.shared().getBy(url: url)
        else { return false }

        let title = "[[\(draggableNote.title)]]"
        DispatchQueue.main.async {
            self.insertText(title, replacementRange: replacementRange)
            self.setSelectedRange(NSRange(location: replacementRange.location + title.count, length: 0))
        }
        
        return true
    }

    public func handleURLs(_ pasteboard: NSPasteboard, note: Note, replacementRange: NSRange) -> Bool {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty else { return false }
        note.save(attributed: attributedString())

        for (index, url) in urls.enumerated() {
            fetchDataFromURL(url: url) { data, error in
                guard let data = data, error == nil else { return }

                DispatchQueue.main.async {
                    if url.isWebURL {
                        let title = self.getHTMLTitle(from: data) ?? url.lastPathComponent
                        self.insertText("[\(title)](\(url.absoluteString))", replacementRange: replacementRange)
                    } else if let filePath = ImagesProcessor.writeFile(data: data, url: url, note: note),
                              let fileURL = note.getAttachmentFileUrl(name: filePath.removingPercentEncoding ?? filePath) {

                        let attributed = NSMutableAttributedString(url: fileURL, title: "", path: filePath)
                        if index < urls.count - 1 { attributed.append(NSAttributedString(string: "\n\n")) }

                        self.insertText(attributed, replacementRange: replacementRange)
                        self.setSelectedRange(NSRange(location: replacementRange.location + attributed.length, length: 0))
                        self.viewDelegate?.notesTableView.reloadRow(note: note)
                    }
                }
            }
        }
        return true
    }
}
