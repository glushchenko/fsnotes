//
//  FileManager+.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 07.02.2021.
//  Copyright © 2021 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension FileManager {
    func directoryExists(atUrl url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = self.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
