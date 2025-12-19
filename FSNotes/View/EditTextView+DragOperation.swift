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
            let draggableNote = Storage.shared().getBy(url: url),
            let textStorage = self.textStorage
        else { return false }
        
        let title = "[[\(draggableNote.title)]]"
        
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
            
            guard let undoManager = self.undoManager else { return }
            undoManager.beginUndoGrouping()
            
            if self.shouldChangeText(in: replacementRange, replacementString: title) {
                textStorage.replaceCharacters(in: replacementRange, with: title)
                self.didChangeText()
                
                self.setSelectedRange(NSRange(location: replacementRange.location + title.count, length: 0))
            }
            
            undoManager.endUndoGrouping()
            undoManager.setActionName("Insert Note Reference")
        }
        
        return true
    }

    public func handleURLs(_ pasteboard: NSPasteboard, note: Note, replacementRange: NSRange) -> Bool {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
              !urls.isEmpty else { return false }

        note.save(attributed: attributedString())

        let group = DispatchGroup()
        let total = urls.count
        var results = Array<NSAttributedString?>(repeating: nil, count: total)

        for (index, url) in urls.enumerated() {
            group.enter()
            fetchDataFromURL(url: url) { data, error in
                defer { group.leave() }
                guard let data = data, error == nil else { return }
                
                if url.isWebURL {
                    let title = self.getHTMLTitle(from: data) ?? url.lastPathComponent
                    let text = "[\(title)](\(url.absoluteString))"
                    results[index] = NSAttributedString(string: text)
                } else if let filePath = ImagesProcessor.writeFile(data: data, url: url, note: note),
                          let fileURL = note.getAttachmentFileUrl(
                            name: filePath.removingPercentEncoding ?? filePath
                          ) {
                    let attributed = NSMutableAttributedString(
                        url: fileURL,
                        title: "",
                        path: filePath
                    )
                    results[index] = attributed
                }
            }
        }
        
        group.notify(queue: .main) {
            let final = NSMutableAttributedString()
            for i in 0..<total {
                guard let part = results[i] else { continue }
                final.append(part)
                if i < total - 1 {
                    final.append(NSAttributedString(string: "\n\n"))
                }
            }
            
            self.window?.makeFirstResponder(self)
            
            guard let undoManager = self.undoManager,
                  let textStorage = self.textStorage else {
                
                self.insertText(final, replacementRange: replacementRange)
                self.setSelectedRange(
                    NSRange(location: replacementRange.location + final.length, length: 0)
                )
                self.viewDelegate?.notesTableView.reloadRow(note: note)
                return
            }
            
            undoManager.beginUndoGrouping()
            
            if self.shouldChangeText(in: replacementRange, replacementString: final.string) {
                textStorage.replaceCharacters(in: replacementRange, with: final)
                self.didChangeText()
                
                self.setSelectedRange(
                    NSRange(location: replacementRange.location + final.length, length: 0)
                )
            }
            
            undoManager.endUndoGrouping()
            undoManager.setActionName("Insert URLs")
            
            self.viewDelegate?.notesTableView.reloadRow(note: note)
        }
        
        return true
    }

}
