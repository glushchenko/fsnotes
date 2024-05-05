//
//  EditorViewController+QuickLook.swift
//  FSNotes iOS
//
//  Created by Oleksandr Hlushchenko on 05.05.2024.
//  Copyright © 2024 Oleksandr Hlushchenko. All rights reserved.
//

import QuickLook

extension EditorViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
        guard let quickLookURL = quickLookURL else {
            fatalError("File URL is nil")
        }
        return quickLookURL as QLPreviewItem
    }

    func quickLook(url: URL) {
        let previewController = QLPreviewController()
        previewController.dataSource = self

        quickLookURL = url

        navigationController?.pushViewController(previewController, animated: true)
    }
}
