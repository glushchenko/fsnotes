//
//  SandboxBookmark.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/6/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Cocoa

class SandboxBookmark {
    var bookmarks = [URL: Data]()
    
    func bookmarkPath() -> String
    {
        var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        url = url.appendingPathComponent("Bookmarks.dict")
        
        return url.path
    }
    
    func load() {
        let path = bookmarkPath()
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            bookmarks = NSKeyedUnarchiver.unarchiveObject(withFile: path) as! [URL: Data]
            
            print(bookmarks)
            
            for bookmark in bookmarks {
                restore(bookmark)
            }
        }
    }
    
    func save() {
        let path = bookmarkPath()
        NSKeyedArchiver.archiveRootObject(bookmarks, toFile: path)
    }
    
    func store(url: URL) {
        do {
            let data = try url.bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            bookmarks[url] = data
        } catch {
            Swift.print ("Error storing bookmarks")
        }
        
    }
    
    func restore(_ bookmark: (key: URL, value: Data))
    {
        print("restore")
        
        let restoredUrl: URL?
        var isStale = false
        
        Swift.print ("Restoring \(bookmark.key)")
        do {
            restoredUrl = try URL.init(resolvingBookmarkData: bookmark.value, options: NSURL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        } catch {
            Swift.print ("Error restoring bookmarks")
            restoredUrl = nil
        }
        
        if let url = restoredUrl {
            if isStale {
                Swift.print ("URL is stale")
            } else {
                if !url.startAccessingSecurityScopedResource()
                {
                    Swift.print ("Couldn't access: \(url.path)")
                }
            }
        }
    }
}
