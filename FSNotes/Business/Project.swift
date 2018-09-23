//
//  Project.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/7/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public class Project: Equatable {
    var url: URL
    var label: String
    var isTrash: Bool
    var isCloudDrive: Bool = false
    var isRoot: Bool
    var parent: Project?
    var isDefault: Bool
    var isArchive: Bool

    public var sortBy: SortBy = UserDefaultsManagement.sort
    public var showInCommon: Bool
    public var showInSidebar: Bool = true
    
    init(url: URL, label: String? = nil, isTrash: Bool = false, isRoot: Bool = false, parent: Project? = nil, isDefault: Bool = false, isArchive: Bool = false) {
        self.url = url
        self.isTrash = isTrash
        self.isRoot = isRoot
        self.parent = parent
        self.isDefault = isDefault
        self.isArchive = isArchive

        showInCommon = (isTrash || isArchive) ? false : true

        #if os(iOS)
        if isRoot {
            showInSidebar = false
        }
        #endif

        if let l = label {
            self.label = l
        } else {
            self.label = url.lastPathComponent
        }
        
        isCloudDrive = isCloudDriveFolder(url: url)
        loadSettings()
    }
    
    func fileExist(fileName: String, ext: String) -> Bool {        
        let fileURL = url.appendingPathComponent(fileName + "." + ext)
        
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    public static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.url == rhs.url
    }
    
    private func isCloudDriveFolder(url: URL) -> Bool {
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            
            if FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil), url.path.contains(iCloudDocumentsURL.path) {
                return true
            }
        }
        
        return false
    }
    
    public func getParent() -> Project {
        if isRoot {
            return self
        }
        
        if let parent = self.parent {
            return parent.getParent()
        }
        
        return self
    }
    
    public func getFullLabel() -> String {
        if isRoot {
            return label
        }

        if isTrash {
            return "Trash"
        }

        if isArchive {
            return label
        }
        
        return "\(getParent().getFullLabel()) › \(label)"
    }

    public func saveSettings() {
        if let relativePath = getRelativePath() {
            let keyStore = NSUbiquitousKeyValueStore()
            keyStore.set(["sortBy": showInCommon, "showInCommon": showInCommon, "showInSidebar": showInSidebar], forKey: relativePath)
            keyStore.synchronize()
        }
    }

    public func loadSettings() {
        if let relativePath = getRelativePath() {
            let keyStore = NSUbiquitousKeyValueStore()
            if let settings = keyStore.dictionary(forKey: relativePath) {
                if let common = settings["showInCommon"] as? Bool {
                    self.showInCommon = common
                }

                if let sidebar = settings["showInSidebar"] as? Bool {
                    self.showInSidebar = sidebar
                }

                if let sortString = settings["sortBy"] as? String, let sort = SortBy(rawValue: sortString) {
                    self.sortBy = sort
                }
            }
        }
    }

    public func getRelativePath() -> String? {
        if let iCloudRoot =  FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            return url.path.replacingOccurrences(of: iCloudRoot.path, with: "")
        }

        return nil
    }
}
