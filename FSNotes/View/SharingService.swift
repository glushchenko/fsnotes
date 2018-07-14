//
//  SharingService.swift .swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/14/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

extension ViewController: NSSharingServicePickerDelegate {
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        
        guard let image = NSImage(named: NSImage.Name(rawValue: "copy.png")) else {
            return proposedServices
        }
        
        var share = proposedServices
        let plainText = NSSharingService(title: "Copy Plain Text", image: image, alternateImage: image, handler: {
            self.saveTextAtClipboard()
        })
        share.insert(plainText, at: 0)
        
        let html = NSSharingService(title: "Copy HTML", image: image, alternateImage: image, handler: {
            self.saveHtmlAtClipboard()
        })
        share.insert(html, at: 1)
        
        return share
    }
}
