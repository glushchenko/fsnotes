//
//  File.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 17.02.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

extension Storage {
    public func pullAll(force: Bool = false) {
        guard let projects = getGitProjects() else { return }
        for project in projects {
        #if os(iOS)
            if !force && !project.settings.gitAutoPull {
                continue
            }
        #endif

            var status: String?

            do {
                try project.pull()

                let currentDate = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                let dateString = dateFormatter.string(from: currentDate)

                status = "Successfull auto pull – \(dateString)"
                project.gitStatus = status
            } catch {
                if let error = error as? GitError {
                    status = error.associatedValue()

                }
            }

            #if os(iOS)
                if let status = status {
                    print(status)
                    project.gitStatus = status

                    if let viewController = AppDelegate.getGitVCOptional(for: project) {
                        viewController.setProgress(message: status)
                    }
                }
            #endif
        }
    }

    public func checkGitState() {
        guard let projects = getGitProjects() else { return }
        for project in projects {
            do {
                _ = try project.checkGitState()
            } catch {
                if let error = error as? GitError {
                    project.gitStatus = error.associatedValue()
                }
            }
        }
    }
}
