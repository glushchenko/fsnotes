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
        let projects = getProjects()
        for project in projects {
            if project.isTrash {
                continue
            }

            if project.isRoot || project.isArchive || project.isGitOriginExist()  {
                do {
                    guard project.getGitOrigin() != nil else { continue }
                    try project.pull()
                    
                    print("Pull \(project.label)")
                } catch {
                    if let error = error as? GitError {
                        AppDelegate.gitProgress.log(message: error.associatedValue())
                    }
                    
                    print("Scheduled pull error: \(error)")
                }
            }
        }
    }
}
