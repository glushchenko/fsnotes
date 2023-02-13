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
        
        if UserDefaultsManagement.separateRepo && !rootProject.isCloudProject() {
            return rootProject.url.appendingPathComponent(".git", isDirectory: true)
        }
        
        let repoURL = UserDefaultsManagement.gitStorage.appendingPathComponent(getShortSign() + " - " + rootProject.label + ".git")
        
        return repoURL
    }
    
    public func getRepository() throws -> Repository? {
        let repositoryManager = RepositoryManager()
        let repositoryProject = getRepositoryProject()
        let repoURL = getRepositoryUrl()
        
        // Open
        do {
            let repository = try repositoryManager.openRepository(at: repoURL)
            return repository
        } catch {/*_*/}
        
        // Prepare temporary dir
        let cloneURL = UserDefaultsManagement.gitStorage.appendingPathComponent("tmp")
        
        try? FileManager.default.removeItem(at: cloneURL)
        try? FileManager.default.createDirectory(at: cloneURL, withIntermediateDirectories: true)
        
        // Clone
        if let originString = getGitOrigin(), let origin = URL(string: originString) {
            let repository = try repositoryManager.cloneRepository(from: origin, at: cloneURL, authentication: getHandler())
            
            repository.setWorkTree(path: repositoryProject.url.path)
            let dotGit = cloneURL.appendingPathComponent(".git")
            
            if FileManager.default.directoryExists(atUrl: dotGit) {
                try? FileManager.default.moveItem(at: dotGit, to: repoURL)
                
                return try repositoryManager.openRepository(at: repoURL)
            }
            
            return nil
        }
        
        // Init
        let signature = Signature(name: "FSNotes App", email: "support@fsnot.es")
        let repository = try repositoryManager.initRepository(at: cloneURL, signature: signature)
        repository.setWorkTree(path: repositoryProject.url.path)
        
        let dotGit = cloneURL.appendingPathComponent(".git")
        
        if FileManager.default.directoryExists(atUrl: dotGit) {
            try? FileManager.default.moveItem(at: dotGit, to: repoURL)
            
            return try repositoryManager.openRepository(at: repoURL)
        }
        
        return nil
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
    
    public func getHandler() -> SshKeyHandler? {
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
    
    public func commit(message: String? = nil) throws {
        guard let repository = try getRepository() else { return }
        
        let statuses = Statuses(repository: repository)
        let lastCommit = try? repository.head().targetCommit()
        
        if statuses.workingDirectoryClean == false || lastCommit == nil {
            do {
                let sign = getSign()
                let head = try repository.head().index()
                
                head.add(path: ".")
                try head.save()
                
                if lastCommit == nil {
                    let commitMessage = message ?? "FSNotes Init"
                    _ = try head.createInitialCommit(msg: commitMessage, signature: sign)
                } else {
                    let commitMessage = message ?? "Usual commit"
                    _ = try head.createCommit(msg: commitMessage, signature: sign)
                }
            } catch {
                print("Commit error: \(error)")
            }
        } else {
            print("Commit skipped")
        }
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
        guard let repository = try getRepository() else { return }
        
        if let origin = getGitOrigin() {
            repository.addRemoteOrigin(path: origin)
        }
        
        let handler = getHandler()
        
        let names = try Branches(repository: repository).names(type: .local)
        guard names.count > 0 else { return }
        guard let branchName = names.first?.components(separatedBy: "/").last else { return }
        
        
        let localMaster = try repository.branches.get(name: branchName)
        try repository.remotes.get(remoteName: "origin").push(local: localMaster, authentication: handler)
    }
    
    public func pull() throws {
        guard let repository = try getRepository() else { return }
        
        if let origin = getGitOrigin() {
            repository.addRemoteOrigin(path: origin)
        }
        
        let repositoryProject = getRepositoryProject()
                
        if !UserDefaultsManagement.separateRepo || isCloudProject() {
            repository.setWorkTree(path: repositoryProject.url.path)
        }
                
        let handler = getHandler()
        let sign = getSign()
        
        let remote = repository.remotes
        let origin = try remote.get(remoteName: "origin")
        
        _ = try origin.pull(signature: sign, authentication: handler, project: repositoryProject)
    }
        
    public func isGitOriginExist() -> Bool {
        if let origin = gitOrigin, origin.count > 0 {
            return true
        }
        
        return false
    }
}
