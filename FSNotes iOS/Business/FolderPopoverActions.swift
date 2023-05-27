//
//  FolderPopoverActions.swift
//  FSNotes iOS
//
//  Created by Александр on 27.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

enum FolderPopoverActions: Int {
    case importNote
    case multipleSelection
    case settingsFolder
    case settingsRepository
    case createFolder
    case removeFolder
    case renameFolder
    case removeTag
    case renameTag
    case openInFiles
    case emptyBin
    case encryptFolder
    case decryptFolder
    case lockFolder
    case unLockFolder

    static let description =
        [
            NSLocalizedString("Import Notes", comment: "Main view popover table"),
            NSLocalizedString("Select", comment: "Main view popover table"),
            NSLocalizedString("View Settings", comment: "Main view popover table"),
            NSLocalizedString("Git Settings", comment: "Main view popover table"),
            NSLocalizedString("Create Folder", comment: "Main view popover table"),
            NSLocalizedString("Remove Folder", comment: "Main view popover table"),
            NSLocalizedString("Rename Folder", comment: "Main view popover table"),
            NSLocalizedString("Remove Tag", comment: "Main view popover table"),
            NSLocalizedString("Rename Tag", comment: "Main view popover table"),
            NSLocalizedString("Open in Files.app", comment: "Main view popover table"),
            NSLocalizedString("Empty Bin", comment: "Main view popover table"),
            NSLocalizedString("Encrypt", comment: "Main view popover table"),
            NSLocalizedString("Decrypt", comment: "Main view popover table"),
            NSLocalizedString("Lock", comment: "Main view popover table"),
            NSLocalizedString("Unlock", comment: "Main view popover table"),
        ]

    public func getDescription() -> String {
        return FolderPopoverActions.description[self.rawValue]
    }
}
