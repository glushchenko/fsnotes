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
        if let origin = getRepositoryProject().gitOrigin, origin.count > 0 {
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

        if let origin = project.gitOrigin, origin.count > 0 {
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

    public func initRepository() throws -> Repository? {
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

#if os(iOS)
        if UserDefaultsManagement.gitPrivateKeyData != nil, let rsaURL = GitViewController.getRsaUrl() {
            rsa = rsaURL
        }
#else
        if let accessData = UserDefaultsManagement.gitPrivateKeyData,
            let bookmarks = NSKeyedUnarchiver.unarchiveObject(with: accessData) as? [URL: Data],
            let url = bookmarks.first?.key {
            rsa = url
        }
#endif

        guard let rsaURL = rsa else { return nil }

        let passphrase = UserDefaultsManagement.gitPassphrase
        let sshKeyDelegate = StaticSshKeyDelegate(privateUrl: rsaURL, passphrase: passphrase)
        let handler = SshKeyHandler(sshKeyDelegate: sshKeyDelegate)

        return handler
    }

    public func getSign() -> Signature {
        return Signature(name: "FSNotes App", email: "support@fsnot.es")
    }

    public func commit(message: String? = nil, completionPreAdd:(() -> (Void))? = nil, completionPreCommit:(() -> (Void))? = nil) throws {
        let repository = try getRepository()

        let statuses = Statuses(repository: repository)
        let lastCommit = try? repository.head().targetCommit()

        if statuses.workingDirectoryClean == false || lastCommit == nil {
            do {
                let sign = getSign()
                let head = try repository.head().index()

                if let completionPreAdd = completionPreAdd {
                    completionPreAdd()
                }

                head.add(path: ".")

                try head.save()

                if lastCommit == nil {
                    if let completionPreCommit = completionPreCommit {
                        completionPreCommit()
                    }

                    let commitMessage = message ?? "FSNotes Init"
                    _ = try head.createInitialCommit(msg: commitMessage, signature: sign)
                } else {
                    let commitMessage = message ?? "Usual commit"
                    _ = try head.createCommit(msg: commitMessage, signature: sign)
                }
            } catch {
                AppDelegate.gitProgress.log(message: "Commit error: \(error)")
            }
        } else {
            print("Commit skipped")
        }
    }

    public func isCleanRepo() -> Bool {
        guard let repository = try? getRepository() else { return false }
        let statuses = Statuses(repository: repository)

        return statuses.workingDirectoryClean
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

        AppDelegate.gitProgress.log(message: "Successful git push 👌")
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

        AppDelegate.gitProgress.log(message: "\(label) – successful git pull 👌")
    }

    public func isUseWorkTree() -> Bool {
    #if os(iOS)
        return UserDefaultsManagement.iCloudDrive
    #endif

        return !UserDefaultsManagement.separateRepo || isCloudProject()
    }

    public func isGitOriginExist() -> Bool {
        if let origin = gitOrigin, origin.count > 0 {
            return true
        }

        return false
    }
}
