//
//  NoteMeta.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 17.05.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public struct NoteMeta: Codable {
    var url: URL
    var imageUrl: [URL]?
    var title: String
    var tags: [String]
    var noteDate: Date
    var preview: String
    var modificationDate: Date
    var creationDate: Date
    var pinned: Bool
}
