//
//  Repository.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 9/8/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class FSRepository {
    private var git: FSGit
    private var debug: Bool
    private var project: Project

    init(git: FSGit, debug: Bool, project: Project) {
        self.git = git
        self.debug = debug
        self.project = project
    }

    private func exec(args: [String]) -> String? {
        let env = getEnvironment()

        return git.exec(args: args, env: env)
    }

    public func getEnvironment() -> [String: String] {
        let name = project.getShortSign() + " - " + project.label + ".git"
        var repo = git.getRepositoriesHome().appendingPathComponent(name)

        if project.isUseSeparateRepo() {
            repo = project.url.appendingPathComponent(".git", isDirectory: true)
        }

        var env = ["GIT_DIR": repo.path, "GIT_WORK_TREE": project.url.path]

        return env
    }

    public func getCommits(by fileName: String) -> [FSCommit] {
        var commits = [FSCommit]()
        if let log = exec(args: ["log", "--follow", "--", "\(fileName)"]) {
            let commitsList = log.matchingStrings(regex: "(?:commit) ([0-9a-z]{32})")

            for commit in commitsList {
                if let hash = commit.last {
                    commits.append(FSCommit(hash: hash))
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

    public func checkout(commit: FSCommit, fileName: String) {
        let output = exec(args: ["checkout", commit.getHash(), "\(fileName)"])

        if debug {
            print("Checkout file: \(String(describing: output))")
        }
    }
}
