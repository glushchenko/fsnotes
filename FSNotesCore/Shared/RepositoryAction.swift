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
    case pull
    case push

    var title: String {
        switch self {
        case .initCommit: return "Init/commit"
        case .clonePush: return "Clone/push"
        case .pull: return "Pull"
        case .commit: return "Add/commit"
        case .push: return "Push"
        }
    }
}
