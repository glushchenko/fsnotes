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

    public func getImagesAndFiles() -> [Attachment] {
        return []
    }

    func safeAddAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {

    }

    public static func buildFromRtfd(data: Data) -> NSMutableAttributedString? {
        return nil
    }

    public func getMeta(at location: Int) -> Attachment? {
        return nil
    }
}
