//
//  Note+History.swift
//  FSNotes iOS
//
//  Created by Александр on 14.02.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Compression

extension Note {

    public func getGitPath(history: Bool = false) -> String {
        var path = name

        if let gitPath = getGitPathPrefix() {
            path = gitPath
        }

        if history && isTextBundle(), let contentURL = getContentFileURL() {
            path += "/" + contentURL.lastPathComponent
        }

        return path.recode4byteString()
    }

    public func getGitPathPrefix() -> String? {
        guard let project = getGitProject() else { return nil }

        let relative = url.path.replacingOccurrences(of: project.url.path, with: "")

        if !UserDefaultsManagement.iCloudDrive && relative.startsWith(string: "/private/") {
            return relative.replacingOccurrences(of: "/private/", with: "")
        }

        if relative.first == "/" {
            return String(relative.dropFirst())
        }

        if relative == "" {
            return nil
        }

        return relative
    }

    public func hasGitRepository() -> Bool {
        return project.getGitProject() != nil
    }

    public func getGitProject() -> Project? {
        return project.getGitProject()
    }

    public func saveRevision() throws {
        if hasGitRepository() {
            guard let project = getGitProject() else { return }
            try project.saveRevision(commitMessage: nil)
            return
        }

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

            if #available(iOS 13.0, macOS 10.15, *) {
                let data = NSData(contentsOf: url)
                if let compressed = try? data?.compressed(using: .lz4) {
                    try? compressed.write(to: noteUrl, options: .atomic)
                }
            } else {
                try? FileManager.default.copyItem(at: url, to: noteUrl)
            }
        }
    }

    public func dropRevisions() {
        do {
            if let repository = getRepositoryUrl() {
                try FileManager.default.removeItem(at: repository)
            }
        } catch {
            print("Repository removing \(error)")
        }
    }

    public func restore(revision: Revision) {
        if hasGitRepository() {
            checkout(commit: revision.commit!)
            forceLoad()
            return
        }

        guard let url = revision.url, !isEncrypted() else { return }

        dropImagesCache()

        if !isVersionExist(checkSum: countCheckSum()) {
            do {
                try saveRevision()
            } catch {/*_*/}
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

            if #available(iOS 13.0, macOS 10.15, *) {
                let data = NSData(contentsOf: src)
                if let content = try? data?.decompressed(using: .lz4) {
                    let options = getDocOptions()
                    if let attributedString = try? NSAttributedString(data: content as Data, options: options, documentAttributes: nil) {
                        self.content = NSMutableAttributedString(attributedString: attributedString)
                        save()

                        restoreInlineFiles(url: url, content: attributedString.string)
                    }
                }
            } else {
                if let content = getAltContent(url: src) {
                    self.content = NSMutableAttributedString(attributedString: content)
                    save()

                    restoreInlineFiles(url: url, content: content.string)
                }
            }
        }

        forceLoad()
    }

    public func listRevisions() -> [Revision] {
        if hasGitRepository() {
            var result = [Revision]()
            let commits = getCommits()
            for commit in commits {
                let timestamp = commit.date.timeIntervalSince1970
                result.append(Revision(timestamp: timestamp, commit: commit))
            }
            return result
        }

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

        var result = [Revision]()
        for timestamp in timestamps {
            if let url = dict[timestamp] {
                result.append(Revision(timestamp: timestamp, url: url))
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

    public func moveHistory(src: URL, dst: URL) {
        let srcFileName = src.lastPathComponent
        let dstFileName = dst.lastPathComponent

        var srcProject = project.getHistoryURL()
        var dstProject = project.getHistoryURL()

        if let dstHistory = project.storage.getProjectBy(url: dst.deletingLastPathComponent())?.getHistoryURL() {

            if !FileManager.default.directoryExists(atUrl: dstHistory) {
                try? FileManager.default.createDirectory(at: dstHistory, withIntermediateDirectories: true, attributes: nil)
            }

            dstProject = dstHistory
        }

        if let srcHistory = project.storage.getProjectBy(url: src.deletingLastPathComponent())?.getHistoryURL(),
            FileManager.default.directoryExists(atUrl: srcHistory) {

            srcProject = srcHistory
        }

        guard let srcDir = srcProject?.appendingPathComponent(srcFileName),
              FileManager.default.fileExists(atPath: srcDir.path),
              let dstDir = dstProject?.appendingPathComponent(dstFileName),
              !FileManager.default.directoryExists(atUrl: dstDir)
        else { return }

        do {
            try FileManager.default.moveItem(at: srcDir, to: dstDir)
        } catch {
            print("History transfer \(error)")
        }
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

    public func getCommits() -> [Commit] {
        var commits = [Commit]()

        do {
            guard let project = getGitProject(), project.hasCommitsDiffsCache() else { return commits }

            let repository = try project.getRepository()
            let path = getGitPath(history: true)

            do {
                let fileRevLog = try FileHistoryIterator(repository: repository, path: path, project: project)
                let oids = fileRevLog.walk()

                for oid in oids {
                    if let commit = try? repository.commitLookup(oid: oid) {
                        commits.append(commit)
                    }
                }

                if fileRevLog.checkFirstCommit() {
                    if let oid = fileRevLog.getLast(), let commit = try? repository.commitLookup(oid: oid) {
                        commits.append(commit)
                    }
                }
            } catch {/*_*/}

            return commits
        } catch {
            print(error)
        }

        return commits
    }

    public func checkout(commit: Commit) {
        do {
            guard let repository = try getGitProject()?.getRepository() else { return }
            let commit = try repository.commitLookup(oid: commit.oid)
            try repository.checkout(commit: commit, path: getGitPath())
            print("Successful checkout")
        } catch {
            print(error)
        }
    }
}

public struct Revision {
    var timestamp: Double
    var url: URL?
    var commit: Commit?
}
