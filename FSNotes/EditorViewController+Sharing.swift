//
//  EditorViewController+Sharing.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 03.07.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa
import WebKit

extension EditorViewController: NSSharingServicePickerDelegate {

    // Retained reference to keep PDFExporter alive during async export
    private static var activePDFExporter: AnyObject?

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        var share = proposedServices

        if #available(macOS 11.0, *) {
            guard let image = NSImage(systemSymbolName: "document.on.document", accessibilityDescription: nil),
                  let webImage = NSImage(named: "web") else {

                return proposedServices
            }

            let titleWeb = NSLocalizedString("Web", comment: "")
            let web = NSSharingService(title: titleWeb, image: webImage, alternateImage: nil, handler: {
                ViewController.shared()?.uploadWebNote(NSMenuItem())
            })
            share.insert(web, at: 0)

            let titlePlain = NSLocalizedString("Copy Plain Text", comment: "")
            let plainText = NSSharingService(title: titlePlain, image: image, alternateImage: image, handler: {
                self.saveTextAtClipboard()
            })
            share.insert(plainText, at: 1)

            let titleHTML = NSLocalizedString("Copy HTML", comment: "")
            let html = NSSharingService(title: titleHTML, image: image, alternateImage: image, handler: {
                self.saveHtmlAtClipboard()
            })
            share.insert(html, at: 2)

            // Share as PDF
            let pdfImage = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil) ?? image
            let titlePDF = NSLocalizedString("Share as PDF", comment: "")
            let sharePDF = NSSharingService(title: titlePDF, image: pdfImage, alternateImage: nil, handler: {
                self.shareAsPDF()
            })
            share.insert(sharePDF, at: 3)

            // Share note file (TextBundle or markdown file)
            let fileImage = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) ?? image
            let titleFile = NSLocalizedString("Share Note File", comment: "")
            let shareFile = NSSharingService(title: titleFile, image: fileImage, alternateImage: nil, handler: {
                self.shareNoteFile()
            })
            share.insert(shareFile, at: 4)
        }

        return share
    }

    //MARK: Share Service

    public func saveTextAtClipboard() {
        if let note = vcEditor?.note {
            let unloadedText = note.content.unloadTasks()
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(unloadedText.string, forType: NSPasteboard.PasteboardType.string)
        }
    }

    public func saveHtmlAtClipboard() {
        if let note = vcEditor?.note {
            let unloadedText = note.content.unloadTasks()
            if let render = renderMarkdownHTML(markdown: unloadedText.string) {
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(render, forType: NSPasteboard.PasteboardType.string)
            }
        }
    }

    @available(macOS 11.0, *)
    public func shareAsPDF() {
        guard let note = vcEditor?.note else { return }

        let pdfDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SharePDF")
        try? FileManager.default.removeItem(at: pdfDir)

        guard let indexURL = MPreviewView.buildPage(for: note, at: pdfDir, print: true) else { return }

        let safeName = note.title.replacingOccurrences(of: "/", with: "-")
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(safeName).pdf")

        let exporter = PDFExporter(indexURL: indexURL, outputURL: outputURL) { [weak self] pdfURL in
            EditorViewController.activePDFExporter = nil
            guard let pdfURL = pdfURL else { return }

            let picker = NSSharingServicePicker(items: [pdfURL])
            if let button = self?.findShareButton() {
                picker.show(relativeTo: NSZeroRect, of: button, preferredEdge: .minY)
            }
        }
        EditorViewController.activePDFExporter = exporter
        exporter.export()
    }

    public func shareNoteFile() {
        guard let note = vcEditor?.note else { return }
        let noteURL = note.url

        let picker = NSSharingServicePicker(items: [noteURL])
        if let button = findShareButton() {
            picker.show(relativeTo: NSZeroRect, of: button, preferredEdge: .minY)
        }
    }

    private func findShareButton() -> NSButton? {
        if let vc = self as? NoteViewController {
            return vc.shareButton
        }
        return ViewController.shared()?.shareButton
    }
}
