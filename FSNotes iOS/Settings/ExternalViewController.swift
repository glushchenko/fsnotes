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

        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)

            SandboxBookmark.sharedInstance().save(data: bookmarkData)

            let storage = Storage.shared()
            if storage.projectExist(url: url) {
                return
            }

            let project = Project(
                storage: storage,
                url: url,
                label: url.lastPathComponent,
                isTrash: false,
                isRoot: true,
                isDefault: false,
                isArchive: false,
                isExternal: true
            )

            storage.assignTree(for: project)
            storage.loadNotes(project, loadContent: true)

            UIApplication.getVC().sidebarTableView.insertRows(projects: [project])
            _ = UIApplication.getNC()?.popViewController(animated: true)

            if !UserDefaultsManagement.sidebarIsOpened {
                UIApplication.getVC().toggleSidebar()
            }

            UIApplication.getVC().sidebarTableView.select(project: project)
        } catch {
            print(error)
        }
    }
}
