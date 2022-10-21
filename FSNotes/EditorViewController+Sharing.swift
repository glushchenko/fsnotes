//
//  EditorViewController+Sharing.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 03.07.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Cocoa

extension EditorViewController: NSSharingServicePickerDelegate {
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        
        guard let image = NSImage(named: "copy.png"), let webImage = NSImage(named: "web") else {
            return proposedServices
        }
        
        var share = proposedServices
        
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
        
        return share
    }
    
    //MARK: Share Service
        
    public func saveTextAtClipboard() {
        if let note = vcEditor?.note {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(note.content.string, forType: NSPasteboard.PasteboardType.string)
        }
    }
    
    public func saveHtmlAtClipboard() {
        if let note = vcEditor?.note {
            if let render = renderMarkdownHTML(markdown: note.content.string) {
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(render, forType: NSPasteboard.PasteboardType.string)
            }
        }
    }
}
