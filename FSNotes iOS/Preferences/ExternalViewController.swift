//
//  ExternalViewController.swift
//  FSNotes iOS
//
//  Created by Александр on 20.02.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit

class ExternalViewController: UIDocumentPickerViewController, UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard urls.count == 1, let url = urls.first, url.hasDirectoryPath else { return }
        guard url.startAccessingSecurityScopedResource() else {
            return
        }

        var accessTransferred = false
        defer {
            if !accessTransferred {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)

            SandboxBookmark.sharedInstance().save(data: bookmarkData, accessing: url)
            accessTransferred = true

            let storage = Storage.shared()
            if storage.projectExist(url: url) {
                return
            }
            
            if let projects = Storage.shared().insert(url: url, bookmark: true) {
                OperationQueue.main.addOperation {
                    UIApplication.getVC().sidebarTableView.insertRows(projects: projects) {
                        if let project = projects.first {
                            UIApplication.getVC().sidebarTableView.select(project: project)
                        }
                    }
                    _ = UIApplication.getNC()?.popViewController(animated: true)
                    
                    if !UserDefaultsManagement.sidebarIsOpened {
                        UIApplication.getVC().openSidebar()
                    }
                }
            }
        } catch {
            print(error)
        }
    }
}
