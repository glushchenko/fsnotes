//
//  Project+Git.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 31.10.2022.
//  Copyright © 2022 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

extension Project {
    public func getGitOrigin() -> String? {
        if let origin = settings.gitOrigin, origin.count > 0 {
            return origin
        }

        return nil
    }

#if os(OSX)
    public func getRepositoryUrl() -> URL {
        if UserDefaultsManagement.separateRepo && !isCloudProject() {
            return url.appendingPathComponent(".git", isDirectory: true)
        }

        let key = String(url.path.md5.prefix(4))
        let repoURL = UserDefaultsManagement.gitStorage.appendingPathComponent(key + " - " + label + ".git")

        return repoURL
    }
#else
    public func getRepositoryUrl() -> URL {
        let key = settingsKey.md5.prefix(6)
        let repoURL = UserDefaultsManagement.gitStorage.appendingPathComponent(key + " - " + label + ".git")

        return repoURL
    }
#endif

    public func hasRepository() -> Bool {
        let url = getRepositoryUrl()

        return FileManager.default.fileExists(atPath: url.path)
    }

    public func getGitProject() -> Project? {
        if hasRepository() {
            return self
        }

        if let parent = parent, let root = parent.getGitProject() {
            return root
        }

        return nil
    }

    public func initBareRepository() throws {
        let repositoryManager = RepositoryManager()
        let repoURL = getRepositoryUrl()

        // Prepare temporary dir
        let tempURL = UserDefaultsManagement.gitStorage.appendingPathComponent("tmp")

        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        // Init
        let signature = Signature(name: "FSNotes App", email: "support@fsnot.es")
        let repository = try repositoryManager.initRepository(at: tempURL, signature: signature)

        if isUseWorkTree() {
            repository.setWorkTree(path: url.path)
        }

        let dotGit = tempURL.appendingPathComponent(".git")

        if FileManager.default.directoryExists(atUrl: dotGit) {
            try? FileManager.default.moveItem(at: dotGit, to: repoURL)
        }
    }

    public func cloneRepository() throws -> Repository? {
        let repositoryManager = RepositoryManager()
        let repoURL = getRepositoryUrl()

        // Prepare temporary dir
        let tempURL = UserDefaultsManagement.gitStorage.appendingPathComponent("tmp")

        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        // Clone
        if let originString = getGitOrigin(), let origin = URL(string: originString) {
            let repository = try repositoryManager.cloneRepository(from: origin, at: tempURL, authentication: getAuthHandler())

            if isUseWorkTree() {
                repository.setWorkTree(path: url.path)
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
        guard let storagePath = UserDefaultsManagement.storagePath,
              let documentsProject = UserDefaultsManagement.iCloudDocumentsContainer else { return false }

        if storagePath == documentsProject.path, url.path.contains(storagePath) {
            return true
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
        let repository = try getRepository()
        let statuses = Statuses(repository: repository)
        let lastCommit = try? repository.head().targetCommit()

        // Add all and save index
        let head = try repository.head().index()
        if let progress = progress {
            progress.log(message: "git add .")
        }
        head.add(path: ".")
        try head.save()

        // Check directory is clean
        if statuses.workingDirectoryClean == false || lastCommit == nil {
            do {
                progress?.log(message: "git commit")

                let sign = getSign()
                if lastCommit == nil {
                    let commitMessage = message ?? "FSNotes Init"
                    _ = try head.createInitialCommit(msg: commitMessage, signature: sign)
                } else {
                    let commitMessage = message ?? "Usual commit"
                    _ = try head.createCommit(msg: commitMessage, signature: sign)
                }

                progress?.log(message: "git commit done 🤟")

                cacheHistory(progress: progress)
            } catch {
                progress?.log(message: "commit error: \(error)")
            }
        } else {
            progress?.log(message: "git add: no new data")
        }
    }

    public func checkGitState() throws -> Bool {
        let repository = try getRepository()
        let statuses = Statuses(repository: repository)

        isCleanGit = statuses.workingDirectoryClean
        return isCleanGit
    }

    public func getLocalBranch(repository: Repository) -> Branch? {
        do {
            let names = try Branches(repository: repository).names(type: .local)

            guard names.count > 0 else { return nil }
            guard let branchName = names.first?.components(separatedBy: "/").last else { return nil }

            let localMaster = try repository.branches.get(name: branchName)
            return localMaster
        } catch {/**/}

        return nil
    }

    public func push(progress: GitProgress? = nil) throws {
        guard let origin = getGitOrigin() else { return }

        let repository = try getRepository()
        repository.addRemoteOrigin(path: origin)

        let handler = getAuthHandler()

        let names = try Branches(repository: repository).names(type: .local)
        guard names.count > 0 else { return }
        guard let branchName = names.first?.components(separatedBy: "/").last else { return }

        let localMaster = try repository.branches.get(name: branchName)
        try repository.remotes.get(remoteName: "origin").push(local: localMaster, authentication: handler)

        if let progress = progress {
            progress.log(message: "\(label) – successful push 👌")
        }
    }

    public func pull(progress: GitProgress? = nil) throws {
        guard let origin = getGitOrigin() else { return }

        let repository = try getRepository()
        repository.addRemoteOrigin(path: origin)

        if isUseWorkTree() {
            repository.setWorkTree(path: url.path)
        }

        let authHandler = getAuthHandler()
        let sign = getSign()

        let remote = repository.remotes
        let remoteBranch = try remote.get(remoteName: "origin")

        _ = try remoteBranch.pull(signature: sign, authentication: authHandler, project: self)

        if let progress = progress {
            progress.log(message: "\(label) – successful git pull 👌")
        }
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

        if FileManager.default.fileExists(atPath: repoURL.path) {
            try? FileManager.default.removeItem(at: repoURL)
        }

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

            let cacheData = try? NSKeyedArchiver.archivedData(withRootObject: commitsCache, requiringSecureCoding: false)
            if let data = cacheData, let writeTo = getCommitsDiffsCache() {
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
        let fileName = "commitsDiff-\(settingsKey).cache"
        return documentDir.appendingPathComponent(fileName, isDirectory: false)
    }

    public func getRepositoryState() -> RepositoryAction {
        if hasRepository() {
            if settings.gitOrigin != nil {
                return .pull
            } else {
                return .commit
            }
        } else {
            if settings.gitOrigin != nil {
                return .clonePush
            } else {
                return .initCommit
            }
        }
    }

    public func gitDo(_ action: RepositoryAction, progress: GitProgress? = nil) -> String? {
        var message: String?

        do {
            switch action {
            case .initCommit:
                try initBareRepository()
                try commit(message: nil, progress: progress)
            case .clonePush:
                message = clonePush(progress: progress)
            case .commit:
                try commit(message: nil, progress: progress)
            case .pull:
                try pull(progress: progress)
            case .push:
                try push()
            }
        } catch {
            message = error.localizedDescription
        }

        return message
    }

    private func clonePush(progress: GitProgress? = nil) -> String? {
        var message: String?

        do {
            if let repo = try cloneRepository(), let local = getLocalBranch(repository: repo) {
                try repo.head().forceCheckout(branch: local)
                cacheHistory(progress: progress)
            } else {
                do {
                    try commit(message: nil, progress: progress)
                    try push(progress: progress)
                } catch {
                    message = error.localizedDescription
                }
            }
        } catch GitError.unknownError(let errorMessage, _, let desc) {
            message = errorMessage + " – " + desc
        } catch GitError.notFound(let ref) {

            // Empty repository – commit and push
            if ref == "refs/heads/master" {
                do {
                    try commit(message: nil, progress: progress)
                    try push(progress: progress)
                } catch {
                    message = error.localizedDescription
                }
            }
        } catch {
            message = error.localizedDescription
        }

        return message
    }
}
