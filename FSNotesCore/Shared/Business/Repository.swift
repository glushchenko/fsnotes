//
//  Repository.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 9/8/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class Repository {
    private var git: Git
    private var name: String
    private var workTree: URL

    init(git: Git, name: String, workTree: URL) {
        self.git = git
        self.name = name
        self.workTree = workTree
    }

    public func getEnvironment() -> [String: String] {
        let repoName = "\(name).git"
        let repo = git.getRepositoriesHome().appendingPathComponent(repoName)
        return ["GIT_DIR": repo.path, "GIT_WORK_TREE": workTree.path]
    }

    public func initialize() {
        let repoName = "\(name).git"
        let repo = git.getRepositoriesHome().appendingPathComponent(repoName)

        if FileManager.default.fileExists(atPath: repo.path) {
            print("Repository at this path already exist!")
            return
        }

        let env = getEnvironment()
        let output = git.exec(args: ["init"], env: env)

        print(output)
    }

    public func commitAll() {
        let env = getEnvironment()
        let add = git.exec(args: ["add", "."], env: env)
        let commit = git.exec(args: ["commit", "-m", "'Note update'"], env: env)

        print(add)
        print(commit)
    }

    public func commits(for fileName: String) -> [Commit] {
        let repoName = "\(name).git"
        let repo = git.getRepositoriesHome().appendingPathComponent(repoName)
        let env = ["GIT_DIR": repo.path]

        var commits = [Commit]()
        if let log = git.exec(args: ["log", "--follow", "--", "\(fileName)"], env: env) {
            print("LOG:")
            print(log)

            let commitsList = log.matchingStrings(regex: "(?:commit) ([0-9a-z]{32})")

            for commit in commitsList {
                if let ident = commit.last {
                    commits.append(Commit(id: ident))
                }
            }

            let datesList = log.matchingStrings(regex: "(?:Date):   ([^\\n]*)")
            var dateId = 0
            for date in datesList {
                if let dateString = date.last {
                    commits[dateId].setDate(date: dateString)
                }
                dateId += 1
            }
        }

        return commits
    }

    public func checkout(commit: Commit, fileName: String) {
        let env = getEnvironment()
        let log = git.exec(args: ["checkout", commit.getId(), "\(fileName)"], env: env)
        print(log)
    }
}
