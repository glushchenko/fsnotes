//
//  SearchQuery.swift
//  FSNotes iOS
//
//  Created by Александр on 23.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

class SearchQuery {
    var type: SidebarItemType? = nil
    var projects: [Project]? = nil
    var tags: [String]? = nil
    var terms: [Substring]? = nil
    var filter: String? = nil

    init() {}

    init(type: SidebarItemType) {
        if type == .Todo {
            terms = ["- [ ] "]
        }

        self.type = type
    }

    init(filter: String) {
        self.filter = filter

        terms = filter.split(separator: " ")
    }

    init(type: SidebarItemType, projects: [Project]? = nil, tags: [String]? = nil) {
        if type == .Todo {
            terms = ["- [ ] "]
        }

        self.type = type

        if let projects = projects {
            self.projects = projects
        }

        if let tags = tags {
            self.tags = tags
        }
    }

    public func setType(_ type: SidebarItemType) {
        if type == .Todo {
            if terms?.count == 0 {
                terms = ["- [ ] "]
            } else {
                terms!.append("- [ ] ")
            }
        }

        self.type = type
    }

    public func getFilter() -> String? {
        return self.filter
    }

    public func setFilter(_ filter: String) {
        self.filter = filter
        
        terms = filter.split(separator: " ")
    }

    public func isEmptyFilter() -> Bool {
        return self.filter == nil || self.filter?.count == 0
    }

    public func isFit(note: Note) -> Bool {
        return !note.name.isEmpty
            && (
                self.isEmptyFilter() && self.type != .Todo
                    || self.type == .Todo && self.isMatched(note: note, terms: ["- [ ]"])
                    || self.terms != nil && self.isMatched(note: note, terms: self.terms!)
            ) && (
                self.type == .All && note.project.isVisibleInCommon()
                || self.type != .All && self.type != .Todo && self.projects != nil && self.projects!.contains(note.project)
                || self.type == .Inbox && note.project.isDefault
                || self.type == .Trash
                || self.type == .Untagged && note.tags.count == 0
                || self.type == .Todo && note.project.settings.showInCommon
                || !UserDefaultsManagement.inlineTags && self.tags != nil
                || self.projects?.contains(note.project) == true
            ) && (
                self.type == .Trash && note.isTrash()
                || self.type != .Trash && !note.isTrash()
            ) && (
                self.tags == nil
                || UserDefaultsManagement.inlineTags && self.tags != nil && note.tags.filter({ self.tags != nil && self.contains(tag: $0, in: self.tags!) }).count > 0
            ) && !(
                note.project.isEncrypted &&
                note.project.isLocked()
            )
    }

    public func contains(tag name: String, in tags: [String]) -> Bool {
        var found = false
        for tag in tags {
            if name == tag || name.starts(with: tag + "/") {
                found = true
                break
            }
        }
        return found
    }

    private func isMatched(note: Note, terms: [Substring]) -> Bool {
        for term in terms {
            if note.name.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: nil) != nil ||
                note.content.string.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: nil) != nil {
                continue
            }

            return false
        }

        return true
    }
}
