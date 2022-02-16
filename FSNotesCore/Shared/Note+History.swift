//
//  Note+History.swift
//  FSNotes iOS
//
//  Created by Александр on 14.02.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension Note {
    public func saveRevision() {
        guard
            !isEncrypted(),
            let versionUrl = createVersionUrl(),
            !isVersionExist(checkSum: countCheckSum()),
            !FileManager.default.directoryExists(atUrl: versionUrl) else { return }

        try? FileManager.default.createDirectory(at: versionUrl, withIntermediateDirectories: true, attributes: nil)

        if isTextBundle() {
            if let fileList = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
                for item in fileList {
                    let srcUrl = url.appendingPathComponent(item)
                    let dstUrl = versionUrl.appendingPathComponent(item)
                    try? FileManager.default.copyItem(at: srcUrl, to: dstUrl)
                }
            }
        }

        if container == .none {
            saveInlineFiles(url: versionUrl)

            let noteUrl = versionUrl.appendingPathComponent("file.data")
            try? FileManager.default.copyItem(at: url, to: noteUrl)
        }
    }

    public func restoreRevision(url: URL) {
        guard !isEncrypted() else { return }

        dropImagesCache()

        if !isVersionExist(checkSum: countCheckSum()) {
            saveRevision()
        }

        if isTextBundle() {
            if let content = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
                for item in content {
                    let src = url.appendingPathComponent(item)
                    let dst = self.url.appendingPathComponent(item)
                    try? FileManager.default.removeItem(at: dst)
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        }

        if container == .none {
            dropInlineFiles()

            let src = url.appendingPathComponent("file.data")

            if let content = getAltContent(url: src) {
                self.content = NSMutableAttributedString(attributedString: content)
                save()

                restoreInlineFiles(url: url, content: content.string)
            }
        }

        forceLoad()
    }

    public func listRevisions() -> [TimestampUrl] {
        guard let revisions = getRepositoryUrl(),
              let dirs = try? FileManager.default.contentsOfDirectory(atPath: revisions.path) else { return [] }

        var dict = [Double: URL]()
        for dir in dirs {
            let items = dir.split(separator: "-")
            if let timestamp = Double(items[0]) {
                if items.count > 1 {
                    dict[timestamp] = revisions.appendingPathComponent(String(dir))
                }
            }
        }

        var timestamps = dirs.map({ Double( $0.split(separator: "-")[0] )! })
        timestamps.sort(by: {$0 > $1})

        var result = [TimestampUrl]()
        for timestamp in timestamps {
            if let url = dict[timestamp] {
                result.append(TimestampUrl(timestamp: timestamp, url: url))
            }
        }

        return result
    }

    private func getChecksumList() -> [String] {
        guard let revisions = getRepositoryUrl(),
              let dirs = try? FileManager.default.contentsOfDirectory(atPath: revisions.path) else { return [] }

        var result = [String]()
        for dir in dirs {
            let items = dir.split(separator: "-")
            if items.count > 1 {
                result.append(String(items[1]))
            }
        }

        return result
    }

    private func isVersionExist(checkSum: String) -> Bool {
        let checkSumList = getChecksumList()

        return checkSumList.contains(checkSum)
    }

    private func createVersionUrl() -> URL? {
        guard let historyURL = getRepositoryUrl() else { return nil }

        let timestamp = String(Date().timeIntervalSince1970) + "-" + countCheckSum()
        let revisionURL = historyURL.appendingPathComponent(timestamp)

        return revisionURL
    }

    private func getRepositoryUrl() -> URL? {
        guard let url = project.getHistoryURL() else { return nil }

        return url.appendingPathComponent(name)
    }

    private func dropInlineFiles() {
        let content = self.content.string

        let fullRange = NSRange(0..<content.utf16.count)
        let options = NSRegularExpression.MatchingOptions(rawValue: 0)

        FSParser.imageInlineRegex.regularExpression.enumerateMatches(in: content, options: options, range: fullRange, using: { (result, _, _) -> Void in

            guard let range = result?.range(at: 3), content.count >= range.location else { return }
            let imagePath = content.substring(with: range)?.removingPercentEncoding

            if let imagePath = imagePath {
                let src = self.project.url.appendingPathComponent(imagePath)
                do {
                    try FileManager.default.removeItem(at: src)
                } catch {
                    print("Inline image removing \(error)")
                }
            }
        })
    }

    private func saveInlineFiles(url: URL) {
        let content = self.content.string

        let fullRange = NSRange(0..<content.utf16.count)
        let options = NSRegularExpression.MatchingOptions(rawValue: 0)

        FSParser.imageInlineRegex.regularExpression.enumerateMatches(in: content, options: options, range: fullRange, using: { (result, _, _) -> Void in

            guard let range = result?.range(at: 3), content.count >= range.location else { return }
            let imagePath = content.substring(with: range)?.removingPercentEncoding

            if let imagePath = imagePath {
                let src = self.project.url.appendingPathComponent(imagePath)
                let dst = url.appendingPathComponent(imagePath)

                let dstDir = dst.deletingLastPathComponent()
                if !FileManager.default.directoryExists(atUrl: dstDir) {
                    do {
                        try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        print("Create revision dir: \(error)")
                    }
                }

                do {
                    try FileManager.default.copyItem(at: src, to: dst)
                } catch {
                    print("Save revision inline files: \(error)")
                }
            }
        })
    }

    private func restoreInlineFiles(url: URL, content: String) {
        let fullRange = NSRange(0..<content.utf16.count)
        let options = NSRegularExpression.MatchingOptions(rawValue: 0)

        FSParser.imageInlineRegex.regularExpression.enumerateMatches(in: content, options: options, range: fullRange, using: { (result, _, _) -> Void in

            guard let range = result?.range(at: 3), content.count >= range.location else { return }
            let imagePath = content.substring(with: range)?.removingPercentEncoding

            if let imagePath = imagePath {
                let src = url.appendingPathComponent(imagePath)
                let dst = project.url.appendingPathComponent(imagePath)

                if src.isRemote() || !FileManager.default.fileExists(atPath: src.path) {
                    return
                }

                do {
                    try FileManager.default.copyItem(at: src, to: dst)
                } catch {
                    print("Restore inline files: \(error)")
                }
            }
        })
    }
}

public struct TimestampUrl {
    var timestamp: Double
    var url: URL
}
