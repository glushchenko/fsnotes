//
//  SandboxBookmarks.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 7/28/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

class SandboxBookmark {
    static var instance: SandboxBookmark? = nil

    private let bookmarksKey = "SecurityBookmarksKey"
    private var defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults")
    private var bookmarks = [URL: Data]()

    public static func sharedInstance() -> SandboxBookmark {
        guard let sandbox = self.instance else {
            self.instance = SandboxBookmark()
            return self.instance!
        }
        
        return sandbox
    }

    private var storedBookmarks: [Data] {
        return defaults?.array(forKey: bookmarksKey) as? [Data] ?? []
    }

    private func retainAccess(to url: URL) -> Bool {
        let url = url.standardizedFileURL
        if bookmarks[url] != nil {
            return true
        }
        return url.startAccessingSecurityScopedResource()
    }

    private func persist(_ data: [Data]) {
        defaults?.set(data, forKey: bookmarksKey)
    }

    public func load() {
        var saved = storedBookmarks
        var changed = false

        for index in saved.indices {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: saved[index], bookmarkDataIsStale: &isStale)
                    .standardizedFileURL
                guard retainAccess(to: url) else { continue }

                var data = saved[index]
                if isStale {
                    do {
                        data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                        saved[index] = data
                        changed = true
                    } catch {
                        print("Couldn't refresh bookmark: \(error)")
                    }
                }

                bookmarks[url] = data
                print("URL loaded from security scope: \(url)")
            } catch {
                // Keep temporarily unavailable bookmarks so a provider can recover.
                print("Couldn't resolve bookmark: \(error)")
            }
        }

        if changed {
            persist(saved)
        }
    }

    public func save(data: Data) throws {
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
            .standardizedFileURL
        guard retainAccess(to: url) else {
            throw CocoaError(.fileReadNoPermission)
        }

        // Persist from the complete saved list, including unavailable providers.
        var saved = storedBookmarks.filter { existing in
            var stale = false
            guard let existingURL = try? URL(resolvingBookmarkData: existing, bookmarkDataIsStale: &stale) else {
                return true
            }
            return existingURL.standardizedFileURL.path != url.path
        }
        saved.append(data)
        bookmarks[url] = data
        persist(saved)
    }

    public func remove(url: URL) {
        let path = url.standardizedFileURL.path
        let oldStylePath = "/private" + path
        func matches(_ candidate: URL) -> Bool {
            let candidatePath = candidate.standardizedFileURL.path
            return candidatePath == path || candidatePath == oldStylePath
        }

        let saved = storedBookmarks.filter { data in
            var stale = false
            guard let restored = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else {
                return true
            }
            return !matches(restored)
        }

        for restored in Array(bookmarks.keys) where matches(restored) {
            restored.stopAccessingSecurityScopedResource()
            bookmarks.removeValue(forKey: restored)
        }
        persist(saved)
    }

    public func getRestoredUrls() -> [URL] {
        return Array(bookmarks.keys)
    }
}
