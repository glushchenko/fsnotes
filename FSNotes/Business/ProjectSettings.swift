//
//  ProjectSettings.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 03.03.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation

public class ProjectSettings: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { return true }
 
    public var sortBy: SortBy = .none
    public var sortDirection: SortDirection = .desc
    public var showInCommon: Bool = true
    public var showInSidebar: Bool = true
    public var showNestedFoldersContent: Bool = true
    public var firstLineAsTitle: Bool?
    public var priority: Int = 0
    public var gitAutoPull: Bool = false
    public var gitOrigin: String?
    public var gitPrivateKey: Data?
    public var gitPrivateKeyPassphrase: String?
    
    public override init() {/*_*/}
    
    public required init(coder aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(of: NSString.self, forKey: "sortBy") as? String, let sort = SortBy(rawValue: value) {
            sortBy = sort
        }

        if let value =  aDecoder.decodeObject(of: NSString.self, forKey: "sortDirection") as? String, let direction = SortDirection(rawValue: value) {
            sortDirection = direction
        }
        
        showInCommon =  aDecoder.decodeBool(forKey: "showInCommon")
        showInSidebar = aDecoder.decodeBool(forKey: "showInSidebar")
        showNestedFoldersContent = aDecoder.decodeBool(forKey: "showNestedFoldersContent")

        if aDecoder.containsValue(forKey: "firstLineAsTitle") {
            firstLineAsTitle = aDecoder.decodeBool(forKey: "firstLineAsTitle")
        }

        priority = aDecoder.decodeInteger(forKey: "priority")
        gitAutoPull =  aDecoder.decodeBool(forKey: "gitAutoPull")

        if let value = aDecoder.decodeObject(of: NSString.self, forKey: "gitOrigin") as? String {
            gitOrigin = value
        }

        if let value = aDecoder.decodeObject(of: NSData.self, forKey: "gitPrivateKey") as? Data {
            gitPrivateKey = value
        }

        if let value = aDecoder.decodeObject(of: NSString.self, forKey: "gitPrivateKeyPassphrase") as? String {
            gitPrivateKeyPassphrase = value
        }
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(sortBy.rawValue, forKey: "sortBy")
        aCoder.encode(sortDirection.rawValue, forKey: "sortDirection")
        aCoder.encode(showInCommon, forKey: "showInCommon")
        aCoder.encode(showInSidebar, forKey: "showInSidebar")
        aCoder.encode(showNestedFoldersContent, forKey: "showNestedFoldersContent")

        if let firstLineAsTitle = firstLineAsTitle {
            aCoder.encode(firstLineAsTitle, forKey: "firstLineAsTitle")
        }

        aCoder.encode(priority, forKey: "priority")
        aCoder.encode(gitAutoPull, forKey: "gitAutoPull")

        if let gitOrigin = gitOrigin {
            aCoder.encode(gitOrigin, forKey: "gitOrigin")
        }
        
        if let gitPrivateKey = gitPrivateKey {
            aCoder.encode(gitPrivateKey, forKey: "gitPrivateKey")
        }
        
        if let gitPrivateKeyPassphrase = gitPrivateKeyPassphrase {
            aCoder.encode(gitPrivateKeyPassphrase, forKey: "gitPrivateKeyPassphrase")
        }
    }

    public func setOrigin(_ origin: String?) {
        if let origin = origin, origin.count > 0 {
            gitOrigin = origin
            return
        }

        gitOrigin = nil
    }

    public func isFirstLineAsTitle() -> Bool {
        if let firstLineAsTitle = firstLineAsTitle {
            return firstLineAsTitle
        }

        return UserDefaultsManagement.firstLineAsTitle
    }
}
