//
//  SearchQuery.swift
//  FSNotes iOS
//
//  Created by Александр on 23.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

class SearchQuery {
    var type: SidebarItemType? = nil
    var project: Project? = nil
    var tag: String? = nil
    var terms: [Substring]? = nil

    init() {}

    init(type: SidebarItemType) {
        if type == .Todo {
            terms = ["- [ ] "]
        }

        self.type = type
    }

    init(filter: String) {
        terms = filter.split(separator: " ")
    }

    init(type: SidebarItemType, project: Project?, tag: String?) {
        if type == .Todo {
            terms = ["- [ ] "]
        }

        self.type = type
        self.project = project
        self.tag = tag
    }

    public func setType(_ type: SidebarItemType) {
        if type == .Todo {
            terms = ["- [ ] "]
        }

        self.type = type
    }

    public func getFilter() -> String? {
        return terms?.joined(separator: " ")
    }
}
