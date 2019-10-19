//
//  Tag.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 14.10.2019.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

class Tag {
    private var name: String
    private var child = [Tag]()
    private var parent: Tag?

    init(name: String, parent: Tag? = nil) {
        self.name = name
        self.parent = parent

        let tags = name.components(separatedBy: "/")
        if tags.count > 1, let parent = tags.first {
            addChild(name: tags.dropFirst().joined(separator: "/"))
            self.name = parent
            return
        }
    }

    public func appendChild(tag: Tag) {
        child.append(tag)
    }

    public func isExpandable() -> Bool {
        return child.count > 0
    }

    public func addChild(name: String) {
        let tags = name.components(separatedBy: "/")

        if tags.count > 1, let parent = tags.first {
            if let tag = child.first(where: { $0.name == parent }) {
                let newTag = tags.dropFirst().joined(separator: "/")

                tag.appendChild(tag: Tag(name: newTag, parent: tag))
            } else {
                appendChild(tag: Tag(name: name, parent: self))
            }
            return
        }

        guard nil == child.first(where: { $0.name == name }) else { return }

        let tag = Tag(name: name, parent: self)
        child.append(tag)
    }

    public func getChild() -> [Tag] {
        return child
    }

    public func get(name: String) -> Tag? {
        return child.first(where: { $0.name == name })
    }

    public func getName() -> String {
        return name
    }

    public func getFullName() -> String {
        if let parentTag = parent?.getFullName(), parentTag != "" {
            return "\(parentTag)/\(name)"
        }

        if name == "# Tags" {
            return String()
        }

        return "\(name)"
    }
}
