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
    case createFolder
    case removeFolder
    case renameFolder
    case removeTag
    case renameTag
    case openInFiles
    case emptyBin

    static let description =
        [
            NSLocalizedString("Import notes", comment: "Main view popover table"),
            NSLocalizedString("Select", comment: "Main view popover table"),
            NSLocalizedString("View settings", comment: "Main view popover table"),
            NSLocalizedString("Create folder", comment: "Main view popover table"),
            NSLocalizedString("Remove folder", comment: "Main view popover table"),
            NSLocalizedString("Rename folder", comment: "Main view popover table"),
            NSLocalizedString("Remove tag", comment: "Main view popover table"),
            NSLocalizedString("Rename tag", comment: "Main view popover table"),
            NSLocalizedString("Open in Files.app", comment: "Main view popover table"),
            NSLocalizedString("Empty Bin", comment: "Main view popover table"),
        ]

    public func getDescription() -> String {
        return FolderPopoverActions.description[self.rawValue]
    }
}
