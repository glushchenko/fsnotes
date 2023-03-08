//
//  Project+Git.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 31.10.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

extension Project {
    public func getGitPath() -> String? {
        if isArchive || parent == nil {
            return nil
        }

        let parentURL = getRepositoryProject().url
        let relative = url.path.replacingOccurrences(of: parentURL.path, with: "")

        if relative.first == "/" {
            return String(relative.dropFirst())
        }

        if relative == "" {
            return nil
        }

        return relative
    }

    public func getGitOrigin() -> String? {
        if let origin = getRepositoryProject().settings.gitOrigin, origin.count > 0 {
            return origin
        }

        return nil
    }

    public func isRepositoryRoot(project: Project) -> Bool {
        if project.isRoot {
            return true
        }

        if project.isDefault {
            return true
        }

        if project.isArchive {
            return true
        }

        if let origin = project.settings.gitOrigin, origin.count > 0 {
            return true
        }

        return false
    }

    public func getRepositoryProject() -> Project {
        if isRepositoryRoot(project: self) {
            return self
        }

        var parent = self.parent

        while let unwrapedParent = parent {
            if isRepositoryRoot(project: unwrapedParent) {
                return unwrapedParent
            }

            parent = unwrapedParent.parent
        }

        return self
    }

    public func getRepositoryUrl() -> URL {
        let rootProject = getRepositoryProject()

    #if os(iOS)
        if !UserDefaultsManagement.iCloudDrive {
            return rootProject.url.appendingPathComponent(".git", isDirectory: true)
        }
    #endif

        if UserDefaultsManagement.separateRepo && !rootProject.isCloudProject() {
            return rootProject.url.appendingPathComponent(".git", isDirectory: true)
        }

        let repoURL = UserDefaultsManagement.gitStorage.appendingPathComponent(getShortSign() + " - " + rootProject.label + ".git")

        return repoURL
    }

    public func hasRepository() -> Bool {
        let url = getRepositoryUrl()

        return FileManager.default.fileExists(atPath: url.path)
    }

    public func isValidRemoteRepository() -> Bool {
        return settings.gitOrigin != nil && hasRepository()
    }

    public func initBareRepository() throws -> Repository? {
        let repositoryManager = RepositoryManager()
        let repositoryProject = getRepositoryProject()
        let repoURL = getRepositoryUrl()

        // Prepare temporary dir
        let tempURL = UserDefaultsManagement.gitStorage.appendingPathComponent("tmp")

        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        // Init
        let signature = Signature(name: "FSNotes App", email: "support@fsnot.es")
        let repository = try repositoryManager.initRepository(at: tempURL, signature: signature)

        if isUseWorkTree() {
            repository.setWorkTree(path: repositoryProject.url.path)
        }

        let dotGit = tempURL.appendingPathComponent(".git")

        if FileManager.default.directoryExists(atUrl: dotGit) {
            try? FileManager.default.moveItem(at: dotGit, to: repoURL)

            return try repositoryManager.openRepository(at: repoURL)
        }

        return nil
    }

    public func cloneRepository() throws -> Repository? {
        let repositoryManager = RepositoryManager()
        let repositoryProject = getRepositoryProject()
        let repoURL = getRepositoryUrl()

        // Prepare temporary dir
        let tempURL = UserDefaultsManagement.gitStorage.appendingPathComponent("tmp")

        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        // Clone
        if let originString = getGitOrigin(), let origin = URL(string: originString) {
            let repository = try repositoryManager.cloneRepository(from: origin, at: tempURL, authentication: getAuthHandler())

            if isUseWorkTree() {
                repository.setWorkTree(path: repositoryProject.url.path)
            }

            let dotGit = tempURL.appendingPathComponent(".git")

            if FileManager.default.directoryExists(atUrl: dotGit) {
                try? FileManager.default.moveItem(at: dotGit, to: repoURL)

                return try repositoryManager.openRepository(at: repoURL)
            }

            return nil
        }

        return nil
    }

    public func getRepository() throws -> Repository {
        let repositoryManager = RepositoryManager()
        let repoURL = getRepositoryUrl()

        return try repositoryManager.openRepository(at: repoURL)
    }

    public func useSeparateRepo() -> Bool {
        return UserDefaultsManagement.separateRepo && !isCloudProject()
    }

    public func isCloudProject() -> Bool {
        if UserDefaultsManagement.storagePath == UserDefaultsManagement.iCloudDocumentsContainer?.path {
            if url.path == UserDefaultsManagement.storagePath {
                return true
            }

            if getParent().isCloudDrive {
                return true
            }
        }

        return false
    }

    public func getAuthHandler() -> SshKeyHandler? {
        var rsa: URL?

        if let rsaURL = installSSHKey() {
            rsa = rsaURL
        }

        guard let rsaURL = rsa else { return nil }

        let passphrase = settings.gitPrivateKeyPassphrase ?? ""
        let sshKeyDelegate = StaticSshKeyDelegate(privateUrl: rsaURL, passphrase: passphrase)
        let handler = SshKeyHandler(sshKeyDelegate: sshKeyDelegate)

        return handler
    }

    public func getSSHKeyUrl() -> URL? {
        let keyName = getSettingsKey()

        return storage
            .getGitKeysDir()?
            .appendingPathComponent(keyName)
    }

    public func isSSHKeyExist() -> Bool {
        guard let sshKey = getSSHKeyUrl() else { return false }

        if FileManager.default.fileExists(atPath: sshKey.path) {
            return false
        }

        return true
    }

    public func installSSHKey(force: Bool = false) -> URL? {
        guard let url = getSSHKeyUrl() else { return nil }

        if !force, FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        if let key = settings.gitPrivateKey {
            do {
                try key.write(to: url)
                return url
            } catch {/*_*/}
        }

        return nil
    }

    public func getSign() -> Signature {
        return Signature(name: "FSNotes App", email: "support@fsnot.es")
    }

    public func commit(message: String? = nil, progress: GitProgress? = nil) throws {
        var repository: Repository?

        do {
            repository = try getRepository()
        } catch {
            repository = try initBareRepository()
        }

        guard let repository = repository else {
            throw GitError.unknownError(msg: "Repository not found", code: 0, desc: "")
        }

        let statuses = Statuses(repository: repository)
        let lastCommit = try? repository.head().targetCommit()

        if statuses.workingDirectoryClean == false || lastCommit == nil {
            do {
                let sign = getSign()
                let head = try repository.head().index()

                if let progress = progress {
                    progress.log(message: "git add .")
                }

                head.add(path: ".")
                try head.save()

                progress?.log(message: "git commit")

                if lastCommit == nil {
                    let commitMessage = message ?? "FSNotes Init"
                    _ = try head.createInitialCommit(msg: commitMessage, signature: sign)
                } else {
                    let commitMessage = message ?? "Usual commit"
                    _ = try head.createCommit(msg: commitMessage, signature: sign)
                }

                progress?.log(message: "git commit done 🤟")
            } catch {
                progress?.log(message: "commit error: \(error)")
            }
        } else {
            progress?.log(message: "commit error: no new data")
        }
    }

    public func checkGitState() throws -> Bool {
        let repository = try getRepository()
        let statuses = Statuses(repository: repository)

        isCleanGit = statuses.workingDirectoryClean
        return isCleanGit
    }

    public func getLocalBranch(repository: Repository) -> Branch?  {
        do {
            let names = try Branches(repository: repository).names(type: .local)

            guard names.count > 0 else { return nil }
            guard let branchName = names.first?.components(separatedBy: "/").last else { return nil }

            let localMaster = try repository.branches.get(name: branchName)
            return localMaster
        } catch {/**/}

        return nil
    }

    public func push() throws {
        let repository = try getRepository()

        if let origin = getGitOrigin() {
            repository.addRemoteOrigin(path: origin)
        }

        let handler = getAuthHandler()

        let names = try Branches(repository: repository).names(type: .local)
        guard names.count > 0 else { return }
        guard let branchName = names.first?.components(separatedBy: "/").last else { return }

        let localMaster = try repository.branches.get(name: branchName)
        try repository.remotes.get(remoteName: "origin").push(local: localMaster, authentication: handler)
    }

    public func pull() throws {
        let repository = try getRepository()

        if let origin = getGitOrigin() {
            repository.addRemoteOrigin(path: origin)
        }

        let repositoryProject = getRepositoryProject()

        if isUseWorkTree() {
            repository.setWorkTree(path: repositoryProject.url.path)
        }

        let authHandler = getAuthHandler()
        let sign = getSign()

        let remote = repository.remotes
        let origin = try remote.get(remoteName: "origin")

        _ = try origin.pull(signature: sign, authentication: authHandler, project: repositoryProject)
    }

    public func isUseWorkTree() -> Bool {
    #if os(iOS)
        return UserDefaultsManagement.iCloudDrive
    #endif

        return !UserDefaultsManagement.separateRepo || isCloudProject()
    }

    public func isGitOriginExist() -> Bool {
        if let origin = settings.gitOrigin, origin.count > 0 {
            return true
        }

        return false
    }

    public func removeRepository() {
        let repoURL = getRepositoryUrl()
        try? FileManager.default.removeItem(at: repoURL)

        removeCommitsCache()
    }

    public func removeCommitsCache() {
        if let url = getCommitsDiffsCache() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func loadCommitsCache() {
        if !commitsCache.isEmpty {
            return
        }

        if let commitsDiffCache = getCommitsDiffsCache(),
            let data = try? Data(contentsOf: commitsDiffCache),
            let result = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: [String]] {
            commitsCache = result
        }
    }

    public func cacheHistory(progress: GitProgress? = nil) {
        progress?.log(message: "git history caching ...")

        guard let repository = try? getRepository() else { return }

        do {
            let fileRevLog = try FileHistoryIterator(repository: repository, path: "Test", project: self)
            while let _ = fileRevLog.cacheDiff() {/*_*/}

            if let data = try? NSKeyedArchiver.archivedData(withRootObject: commitsCache, requiringSecureCoding: false),
                let writeTo = getCommitsDiffsCache() {

                do {
                    try data.write(to: writeTo)
                } catch {
                    print("Caching error: " + error.localizedDescription)
                }
            }
        } catch {
            print(error)
        }

        progress?.log(message: "git history caching done 🤟")
    }

    public func getCommitsDiffsCache() -> URL? {
        guard let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }

        return documentDir.appendingPathComponent("commitsDiff-\(settingsKey).cache", isDirectory: false)
    }
}
