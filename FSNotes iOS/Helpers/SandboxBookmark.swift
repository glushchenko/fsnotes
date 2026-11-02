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
    private var accessedURLs = [URL: URL]()

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
        let key = url.standardizedFileURL
        if accessedURLs[key] != nil {
            return true
        }
        guard url.startAccessingSecurityScopedResource() else {
            print("Couldn't access bookmarked folder: \(url)")
            return false
        }
        accessedURLs[key] = url
        return true
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
                guard retainAccess(to: url) else { continue }

                if isStale {
                    do {
                        saved[index] = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                        changed = true
                    } catch {
                        print("Couldn't refresh bookmark: \(error)")
                    }
                }
            } catch {
                // Keep temporarily unavailable bookmarks so a provider can recover.
                print("Couldn't resolve bookmark: \(error)")
            }
        }

        if changed {
            persist(saved)
        }
    }

    // Takes ownership of the access already started by the document picker.
    public func save(data: Data, accessing url: URL) {
        let key = url.standardizedFileURL
        if accessedURLs[key] != nil {
            url.stopAccessingSecurityScopedResource()
        } else {
            accessedURLs[key] = url
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

        for restored in Array(accessedURLs.keys) where matches(restored) {
            accessedURLs.removeValue(forKey: restored)?.stopAccessingSecurityScopedResource()
        }
        persist(saved)
    }

    public func getRestoredUrls() -> [URL] {
        return Array(accessedURLs.values)
    }
}
