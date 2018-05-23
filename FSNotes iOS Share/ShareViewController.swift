//
//  ShareViewController.swift
//  FSNotes iOS Share
//
//  Created by Oleksandr Glushchenko on 3/18/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import MobileCoreServices

@objc(ShareViewController)

class ShareViewController: UIViewController {
    private var importData: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let context = self.extensionContext, let input = context.inputItems as? [NSExtensionItem] {
            for item in input {
                if let a = item.attachments as? [NSItemProvider] {
                    for provider in a {
                        if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                            provider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil, completionHandler: { (text, error) in
                                if let data = text as? String {
                                    self.save(text: data)
                                    return
                                }
                            })
                        } else if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                            provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (url, error) in
                                if let data = url as? NSURL, let textLink = data.absoluteString {
                                    self.save(text: textLink)
                                    return
                                }
                            })
                        }
                    }
                }
            }
            
            context.completeRequest(returningItems: context.inputItems, completionHandler: nil)
        }
    }
    
    func save(text: String) {
        guard let defaults = UserDefaults(suiteName: "group.fsnotes-manager") else {
            return
        }
        defaults.synchronize()
        
        if let unhandledData = defaults.array(forKey: "import") as? [String] {
            self.importData = unhandledData
        }
        
        self.importData.append(text)
        defaults.set(self.importData, forKey: "import")
        defaults.synchronize()
        
        if let ext = self.extensionContext {
            ext.completeRequest(returningItems: ext.inputItems, completionHandler: nil)
        }
    }
}
