//
//  File.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 17.02.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

extension Storage {
    public func pullAll() {
        guard let projects = getGitProjects() else { return }
        for project in projects {
            do {
                try project.pull()

                let currentDate = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                let dateString = dateFormatter.string(from: currentDate)

                project.gitStatus = "Successfull auto pull – \(dateString)"
            } catch {
                if let error = error as? GitError {
                    project.gitStatus = error.associatedValue()
                }
            }
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
