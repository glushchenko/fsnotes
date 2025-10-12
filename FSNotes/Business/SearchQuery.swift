//
//  SearchQuery.swift
//  FSNotes iOS
//
//  Created by Александр on 23.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

class SearchQuery {
    var type: SidebarItemType? = nil
    var projects = [Project]()
    var tags = [String]()
    var terms: [Substring]? = nil
    public var filter = String()

    init() {}

    public func setType(_ type: SidebarItemType) {
        if type == .Todo {
            if terms == nil || terms!.count == 0 {
                terms = ["- [ ] "]
            } else {
                terms!.append("- [ ] ")
            }
        }

        self.type = type
    }

    public func setFilter(_ filter: String) {
        self.filter = filter
        
        terms = filter.split(separator: " ")
    }

    public func isFit(note: Note) -> Bool {
        return !note.name.isEmpty
            && (
                self.filter.isEmpty && self.type != .Todo
                    || self.type == .Todo && note.content.hasTodoAttribute()
                    || self.terms != nil && self.isMatched(note: note, terms: self.terms!)
            ) && (
                self.type == .All && note.project.isVisibleInCommon()
                || self.type == .Inbox && note.project.isDefault
                || self.type == .Trash
                || self.type == .Untagged && note.tags.count == 0
                || self.type == .Todo && note.project.settings.showInCommon
                || !UserDefaultsManagement.inlineTags && self.tags.count > 0
                || self.type != .Inbox && self.projects.contains(note.project)
            ) && (
                self.type == .Trash && note.isTrash()
                || self.type != .Trash && !note.isTrash()
            ) && (
                self.tags.count == 0
                || UserDefaultsManagement.inlineTags
                    && self.tags.count > 0
                    && note.tags.filter({ self.tags.count > 0 && self.contains(tag: $0, in: self.tags) }).count > 0
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

    public func dropFilter() {
        self.terms = nil
        self.filter = String()
    }
}
