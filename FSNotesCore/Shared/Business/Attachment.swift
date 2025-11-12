//
//  Attachment.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.10.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

public struct Attachment: Codable {
    public var url: URL
    public var title: String
    public var path: String

    public var data: Data?
    public var preferredName: String?

    public init(url: URL, title: String, path: String, data: Data? = nil) {
        self.url = url
        self.title = title
        self.path = path

        self.data = data
    }

    public init(data: Data, preferredName: String? = nil, title: String? = nil) {
        self.data = data

        if let preferredName = preferredName {
            self.preferredName = preferredName
        }

        self.url = URL(fileURLWithPath: "/non_exist_stub")
        self.path = String()
        self.title = title ?? String()
    }
}
