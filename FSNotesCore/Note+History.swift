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
        guard hasGitRepository() else { return }
        guard let project = getGitProject() else { return }

        try project.saveRevision(commitMessage: nil)
    }

    public func dropRevisions() {
        do {
            if let repository = getRepositoryUrl() {
                try FileManager.default.removeItem(at: repository)
            }
        } catch {/*_*/}
    }

    public func restore(revision: Revision) {
        guard hasGitRepository() else { return }

        checkout(commit: revision.commit!)
        forceLoad()
    }

    public func listRevisions() -> [Revision] {
        guard hasGitRepository() else { return [Revision]() }

        var result = [Revision]()
        let commits = getCommits()
        for commit in commits {
            let timestamp = commit.date.timeIntervalSince1970
            result.append(Revision(timestamp: timestamp, commit: commit))
        }
        return result
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
