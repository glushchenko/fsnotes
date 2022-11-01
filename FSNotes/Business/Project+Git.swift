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

        let parentURL = getGitProject().url
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
        if let origin = gitOrigin, origin.count > 0 {
            return origin
        }
        
        let parentProject = getParent()
        
        if parentProject.isDefault, let origin = UserDefaultsManagement.gitOrigin, origin.count > 0  {
            return UserDefaultsManagement.gitOrigin
        }
        
        if let gitOrigin = parentProject.gitOrigin, gitOrigin.count > 0 {
            return gitOrigin
        }
        
        return nil
    }
    
    public func getGitRepositoryUrl() -> URL {
        if UserDefaultsManagement.separateRepo && !isCloudProject() {
            return url.appendingPathComponent(".git", isDirectory: true)
        }
        
        return UserDefaultsManagement.gitStorage.appendingPathComponent(getShortSign() + " - " + label + ".git", isDirectory: true)
    }
    
    public func isRepoExist() -> Bool {
        let url = getGitRepositoryUrl()
        return FileManager.default.directoryExists(atUrl: url)
    }
    
    public func getRepository() throws -> Repository? {
        if UserDefaultsManagement.separateRepo && !isCloudProject() {
            return getSeparateRepository()
        }
        
        let repositoryManager = RepositoryManager()
        let repoURL = UserDefaultsManagement.gitStorage.appendingPathComponent(getShortSign() + " - " + label + ".git")
        
        do {
            let repository = try repositoryManager.openRepository(at: repoURL)
            return repository
        } catch {
            guard let originString = getGitOrigin(), let origin = URL(string: originString) else { return nil }
            
            let cloneURL = UserDefaultsManagement.gitStorage.appendingPathComponent("tmp")
            try? FileManager.default.removeItem(at: cloneURL)
            
            let repository = try repositoryManager.cloneRepository(from: origin, at: cloneURL, authentication: getHandler())
            
            repository.setWorkTree(path: url.path)
            
            let dotGit = cloneURL.appendingPathComponent(".git")
            
            if FileManager.default.directoryExists(atUrl: dotGit) {
                try? FileManager.default.moveItem(at: dotGit, to: repoURL)
                
                return try repositoryManager.openRepository(at: repoURL)
            }
        }
        
        return nil
    }
    
    public func getSeparateRepository() -> Repository? {
        let repositoryManager = RepositoryManager()
        let repoURL = url.appendingPathComponent(".git", isDirectory: true)
        
        do {
            let repository = try repositoryManager.openRepository(at: repoURL)
            return repository
        } catch {/*_*/}
        
        guard let originString = getGitOrigin(), let origin = URL(string: originString) else { return nil }
        
        let cloneURL = UserDefaultsManagement.gitStorage.appendingPathComponent("tmp")
        try? FileManager.default.removeItem(at: cloneURL)
        
        do {
            _ = try repositoryManager.cloneRepository(from: origin, at: cloneURL, authentication: getHandler())
            let dotGit = cloneURL.appendingPathComponent(".git")
            
            if FileManager.default.directoryExists(atUrl: dotGit) {
                try FileManager.default.moveItem(at: dotGit, to: repoURL)
                
                return try repositoryManager.openRepository(at: repoURL)
            }
        } catch {
            print("Clone error: \(error)")
        }
        
        return nil
    }
    
    public func isUseSeparateRepo() -> Bool {
        return UserDefaultsManagement.separateRepo && !isCloudProject()
    }
    
    public func isCloudProject() -> Bool {
        return UserDefaultsManagement.storagePath == UserDefaultsManagement.iCloudDocumentsContainer?.path
            && url.path == UserDefaultsManagement.storagePath
    }
    
    public func getHandler() -> SshKeyHandler? {
        var rsa: URL?

        if let accessData = UserDefaultsManagement.gitPrivateKeyData,
            let bookmarks = NSKeyedUnarchiver.unarchiveObject(with: accessData) as? [URL: Data],
            let url = bookmarks.first?.key {
            rsa = url
        }
        
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
                
        if !UserDefaultsManagement.separateRepo || isCloudProject() {
            repository.setWorkTree(path: url.path)
        }
                
        let handler = getHandler()
        let sign = getSign()
        
        let remote = repository.remotes
        let origin = try remote.get(remoteName: "origin")
        
        _ = try origin.pull(signature: sign, authentication: handler, project: self)
    }
    
    public func getGitProject() -> Project {
        if isGitOriginExist() {
            return self
        } else {
            return getParent()
        }
    }
    
    public func isGitOriginExist() -> Bool {
        if let origin = gitOrigin, origin.count > 0 {
            return true
        }
        
        return false
    }
}
