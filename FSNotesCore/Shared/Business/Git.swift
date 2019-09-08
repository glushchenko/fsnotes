//
//  Git.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 9/7/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class Git {

    static var instance: Git? = nil

    private var home: URL
    private var repositories: URL
    private var debug: Bool

    public static func sharedInstance() -> Git {
        guard let git = self.instance else {
            self.instance = Git()
            return self.instance!
        }
        return git
    }

    init(debug: Bool = true) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        let repositories = documents.appendingPathComponent("repositories")
        if !FileManager.default.fileExists(atPath: repositories.path) {
            try? FileManager.default.createDirectory(at: repositories, withIntermediateDirectories: true, attributes: nil)
        }

        home = documents.appendingPathComponent("git_home")
        
        self.debug = debug
        self.repositories = repositories

        if !FileManager.default.fileExists(atPath: home.path) {
            do {
                try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Git home dir creation error: \(error) ")
            }
        }

        let configDst = home.appendingPathComponent(".gitconfig")
        let templatesDst = home.appendingPathComponent("templates")

        if !FileManager.default.fileExists(atPath: configDst.path) {
            let resources = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/")
            let configSrc = resources.appendingPathComponent("Initial/git/home/.gitconfig")
            let templatesSrc = resources.appendingPathComponent("Initial/git/home/templates")

            try? FileManager.default.copyItem(at: configSrc, to: configDst)
            try? FileManager.default.copyItem(at: templatesSrc, to: templatesDst)
        }
    }

    public func getRepositoriesHome() -> URL {
        return repositories
    }

    public func exec(args: [String], env: [String: String]? = nil) -> String? {
        let launchPath = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/")
        let process = Process()
        process.launchPath = launchPath.path + "/Initial/git/bin/git"

        var fullEnv = [
            "GIT_CONFIG_NOSYSTEM": "true",
            "HOME": home.path
        ]

        if let env = env {
            fullEnv = env.merging(fullEnv) { $1 }
        }

        print(args)
        process.environment = fullEnv
        process.arguments = args

        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        process.launch()
        process.waitUntilExit()

        //print(process.)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output
        }



        return nil
    }

    public func getVersion() -> String? {
        if let version = exec(args: ["--version"]) {
            return version
        }

        return nil
    }

    public func getRepository(with name: String, workTree: URL) -> Repository {
        return Repository(git: self, name: name, workTree: workTree)
    }
}
