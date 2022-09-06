//
//  Tag.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 14.10.2019.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class FSTag {
    public var name: String
    public var parent: FSTag?

    public var child = [FSTag]()

    init(name: String, parent: FSTag? = nil) {
        self.name = name
        self.parent = parent

        let tags = name.components(separatedBy: "/")
        if tags.count > 1, let parent = tags.first {
            addChild(name: tags.dropFirst().joined(separator: "/"), completion: {(_, _, _) in })
            self.name = parent
            return
        }
    }

    public func load(name: String) {
        self.name = name

        let tags = name.components(separatedBy: "/")
        if tags.count > 1, let parent = tags.first {
            addChild(name: tags.dropFirst().joined(separator: "/"), completion: {(_, _, _) in })
            self.name = parent
            return
        }
    }

    public func isExpandable() -> Bool {
        return child.count > 0
    }

    public func addChild(name: String, completion: (_ tag: FSTag, _ isExist: Bool, _ position: Int) -> Void) {
        let tags = name.components(separatedBy: "/")

        if let index = child.firstIndex(where: { $0.name == tags.first }) {
            completion(child[index], true, index)
        } else {
            let newTag = FSTag(name: name, parent: self)

            let index = getChildPosition(for: newTag)
            child.insert(newTag, at: index)
            completion(newTag, false, index)
        }
    }

    public func getChildPosition(for tag: FSTag) -> Int {
        var tags = child
        tags.append(tag)

        let sorted = tags.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        if let index = sorted.firstIndex(where: { $0 === tag }) {
            return index
        }

        return 0
    }

    public func indexOf(child tag: FSTag) -> Int? {
        return child.firstIndex(where: { $0 === tag })
    }

    public func remove(by index: Int) {
        child.remove(at: index)
    }

    public func removeChild(tag: FSTag) {
        child.removeAll(where: { $0 === tag })
    }

    public func removeParent() {
        parent = nil
    }

    public func get(name: String) -> FSTag? {
        var name = name
        let tags = name.components(separatedBy: "/")

        if tags.count > 1, let parent = tags.first {
            name = parent
        }

        return child.first(where: { $0.name == name })

    }

    public func getName() -> String {
        return name
    }

    public func getFullName() -> String {
        if let parentTag = parent?.getFullName(), parentTag != "" {
            return "\(parentTag)/\(name)"
        }

        if name == NSLocalizedString("Tags", comment: "Sidebar label") {
            return String()
        }

        return "\(name)"
    }

    public func find(name: String) -> FSTag? {
        let tags = name.components(separatedBy: "/")
        let trimmed = tags.dropFirst().joined(separator: "/")

        if let child = get(name: trimmed) {
            if child.name == trimmed {
                return child
            }

            return child.find(name: trimmed)
        }

        return nil
    }

    public func isAlone() -> Bool {
        guard let parent = parent else { return false }

        if parent.child.count == 1 {
            return true
        }

        return false
    }

    public func getParent() -> FSTag? {
        return parent
    }

    public func hasOneChild() -> Bool {
        return child.count < 2
    }

    public func removeAllChild() {
        if child.count < 2 {
            child.removeAll()
        }
    }

    public func getAllChild() -> [String] {
        var tags = [String]()
        tags.append(getFullName())

        var queue = [FSTag]()
        queue.append(contentsOf: child)

        while queue.count > 0 {
            for item in queue {
                tags.append(item.getFullName())
                if item.child.count > 0 {
                    queue.append(contentsOf: item.child)
                }
                queue.removeAll(where: { $0 === item })
            }

            if queue.count == 0 {
                break
            }
        }

        return tags
    }
}
