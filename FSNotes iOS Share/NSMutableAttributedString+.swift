//
//  NSMutableAttributedString+.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 14.11.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

#if os(OSX)
import AppKit
#else
import UIKit
#endif

extension NSMutableAttributedString {

    convenience init(url: URL, title: String = "", path: String) {
        self.init()
    }

    public func unloadImagesAndFiles() -> NSMutableAttributedString {
        return self
    }

    public func loadImagesAndFiles(note: Note) {

    }

    public func unloadTasks() -> NSMutableAttributedString {
        return self
    }

    public func loadTasks() {

    }

    public func unloadAttachments() -> NSMutableAttributedString {
        return self
    }

    public func loadAttachments(_ note: Note) -> NSMutableAttributedString {
        return self
    }

    public func replaceTag(name: String, with replaceString: String) {

    }

    public func getImagesAndFiles() -> [(url: URL, title: String, path: String)] {
        return []
    }

    public func getMeta(at location: Int) -> (url: URL, title: String, path: String)? {
        return nil
    }
}
