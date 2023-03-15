//
//  RepositoryAction.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 13.03.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

public enum RepositoryAction: Int, CaseIterable {
    case initCommit
    case clonePush
    case commit
    case pullPush

    var title: String {
        switch self {
        case .initCommit: return "Init/commit"
        case .clonePush: return "Clone/push"
        case .pullPush: return "Pull/push"
        case .commit: return "Add/commit"
        }
    }
}
