//
//  NSMutableAttributedString+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/21/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#else
import Cocoa
#endif

extension NSMutableAttributedString {
    public func unLoadImages(note: Note? = nil) -> NSMutableAttributedString {
        var offset = 0
        let content = self.mutableCopy() as? NSMutableAttributedString

        self.enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.length)) { (value, range, _) in

            if let textAttachment = value as? NSTextAttachment,
                self.attribute(.todo, at: range.location, effectiveRange: nil) == nil {
                var path: String?
                var title: String?

                let filePathKey = NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.path")
                let titleKey = NSAttributedString.Key(rawValue: "co.fluder.fsnotes.image.title")

                if let filePath = self.attribute(filePathKey, at: range.location, effectiveRange: nil) as? String {

                    path = filePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                    title = self.attribute(titleKey, at: range.location, effectiveRange: nil) as? String
                } else if let note = note,
                    let imageData = textAttachment.fileWrapper?.regularFileContents {
                    path = ImagesProcessor.writeFile(data: imageData, note: note)
                } else if let note = note,
                    let imageData = textAttachment.contents {
                    path = ImagesProcessor.writeFile(data: imageData, note: note)
                }

                let newRange = NSRange(location: range.location + offset, length: range.length)

                guard let unwrappedPath = path, unwrappedPath.count > 0 else { return }

                let unrappedTitle = title ?? ""

                content?.removeAttribute(.attachment, range: newRange)
                content?.replaceCharacters(in: newRange, with: "![\(unrappedTitle)](\(unwrappedPath))")
                offset += 4 + unwrappedPath.count + unrappedTitle.count
            }
        }

        return content!
    }

    public func unLoadCheckboxes() -> NSMutableAttributedString {
        var offset = 0
        let content = self.mutableCopy() as? NSMutableAttributedString

        self.enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.length)) { (value, range, _) in
            if value != nil {
                let newRange = NSRange(location: range.location + offset, length: 1)

                guard range.length == 1,
                    let value = self.attribute(.todo, at: range.location, effectiveRange: nil) as? Int
                else { return }

                var gfm = "- [ ]"
                if value == 1 {
                    gfm = "- [x]"
                }
                content?.replaceCharacters(in: newRange, with: gfm)
                offset += 4
            }
        }

        return content!
    }

    public func unLoad() -> NSMutableAttributedString {
        return unLoadCheckboxes().unLoadImages()
    }

    #if os(OSX)
    public func unLoadUnderlines() -> NSMutableAttributedString {
        self.enumerateAttribute(.underlineStyle, in: NSRange(location: 0, length: self.length)) { (value, range, _) in
            if value != nil {
                self.addAttribute(.underlineColor, value: NSColor.black, range: range)
            }
        }

        return self
    }
    #endif

    public func loadUnderlines() {
        self.enumerateAttribute(.underlineStyle, in: NSRange(location: 0, length: self.length)) { (value, range, _) in
            if value != nil {
                self.addAttribute(.underlineColor, value: Colors.underlineColor, range: range)
            }
        }
    }

    #if os(OSX)
    public func loadCheckboxes() {
        while mutableString.contains("- [ ] ") {
            let range = mutableString.range(of: "- [ ] ")
            if length >= range.upperBound, let unChecked = AttributedBox.getUnChecked() {
                replaceCharacters(in: range, with: unChecked)
            }
        }

        while mutableString.contains("- [x] ") {
            let range = mutableString.range(of: "- [x] ")
            let parRange = mutableString.paragraphRange(for: range)

            if length >= range.upperBound, let checked = AttributedBox.getChecked() {

                let color = UserDataService.instance.isDark ? NSColor.white : NSColor.black
                addAttribute(.strikethroughColor, value: color, range: parRange)
                addAttribute(.strikethroughStyle, value: 1, range: parRange)

                replaceCharacters(in: range, with: checked)
            }
        }
    }
    #endif

    public func replaceCheckboxes() {
        #if IOS_APP || os(OSX)
        while mutableString.contains("- [ ] ") {
            let range = mutableString.range(of: "- [ ] ")
            if length >= range.upperBound, let unChecked = AttributedBox.getUnChecked() {
                replaceCharacters(in: range, with: unChecked)
            }
        }

        while mutableString.contains("- [x] ") {
            let range = mutableString.range(of: "- [x] ")
            if length >= range.upperBound, let checked = AttributedBox.getChecked() {
                replaceCharacters(in: range, with: checked)
            }
        }
        #endif
    }

    public func replaceTag(name: String, with replaceString: String) {
        var scanRange = NSRange(location: 0, length: mutableString.length)
        while true {
            let searchRange = mutableString.range(of: name, options: .caseInsensitive, range: scanRange)
            if searchRange.upperBound > mutableString.length {
                break
            }

            var location = searchRange.location
            var prepend = 0

            if searchRange.location > 0 {
                prepend = 1
                location -= 1
            }

            var length = searchRange.length + prepend
            var append = 0

            if searchRange.location + searchRange.length < mutableString.length {
                append = 1
                length += 1
            }

            let correctedRange = NSRange(location: location, length: length)
            let result = mutableString.substring(with: correctedRange)

            var replaceRange = searchRange

            // drop string
            if replaceString.count == 0 {
                // space OR new line OR start position
                if [" ", "\t", "\n"].contains(result.first) || prepend == 0 {
                    if replaceString.count == 0 {
                        if result.last == "/" {
                            let scanLength = mutableString.length - searchRange.upperBound
                            scanRange = NSRange(location: searchRange.upperBound, length: scanLength)

                            continue
                        }

                        if [" ", "\n"].contains(result.last) {
                            replaceRange = NSRange(location: searchRange.location, length: searchRange.length + 1)
                        }
                    }
                }

                // just replace
                mutableString.replaceCharacters(in: replaceRange, with: replaceString)
            } else {

                // replace only if no tag chars
                if ["/", " ", "\t", "\n"].contains(result.last) || append == 0 {
                    mutableString.replaceCharacters(in: replaceRange, with: replaceString)
                }
            }

            let scanLength = mutableString.length - (searchRange.location + append + replaceString.count)
            if  scanLength <= 0 {
                break
            }

            scanRange = NSRange(location: searchRange.location + replaceString.count + append, length: scanLength)
        }
    }
}
