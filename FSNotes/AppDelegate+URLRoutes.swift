//
//  AppDelegate+URLRoutes.swift
//  FSNotes
//
//  Created by Jeff Hanbury on 13/04/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Cocoa


extension AppDelegate {

    enum HandledSchemes: String {
        case fsnotes = "fsnotes"
        case nv = "nv"
        case nvALT = "nvalt"
    }

    enum FSNotesRoutes: String {
        case find = "find"
        case new = "new"
    }

    enum NvALTRoutes: String {
        case find = "find"
        case blank = ""
        case make = "make"
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
            let scheme = url.scheme
            else { return }

        switch scheme {
        case HandledSchemes.fsnotes.rawValue:
            FSNotesRouter(url)
        case HandledSchemes.nv.rawValue,
             HandledSchemes.nvALT.rawValue:
            NvALTRouter(url)
        default:
            break
        }
    }


    // MARK: - FSNotes routes

    func FSNotesRouter(_ url: URL) {
        guard let directive = url.host else { return }

        switch directive {
        case FSNotesRoutes.find.rawValue:
            RouteFSNotesFind(url)
        case FSNotesRoutes.new.rawValue:
            RouteFSNotesNew(url)
        default:
            break
        }
    }

    /// Handles URLs with the path /find/title
    func RouteFSNotesFind(_ url: URL) {
        let name = url.lastPathComponent
        if let note = storage.getBy(title: name),
            let window = NSApplication.shared.windows.first,
            let controller = window.contentViewController as? ViewController {
            controller.updateTable() {
                controller.notesTableView.setSelected(note: note)
            }
        }
    }

    /// Handles URLs with the following paths:
    ///   - fsnotes://make/?title=URI-escaped-title&html=URI-escaped-HTML-data
    ///   - fsnotes://make/?title=URI-escaped-title&txt=URI-escaped-plain-text
    ///   - fsnotes://make/?txt=URI-escaped-plain-text
    ///
    /// The three possible parameters (title, txt, html) are all optional.
    ///
    func RouteFSNotesNew(_ url: URL) {
        var title = ""
        var body = ""

        if let titleParam = url["title"] {
            title = titleParam
        }

        if let txtParam = url["txt"] {
            body = txtParam
        }
        else if let htmlParam = url["html"] {
            body = htmlParam
        }

        guard let window = NSApplication.shared.windows.first,
            let controller = window.contentViewController as? ViewController
            else { return }

        controller.createNote(name: title, content: body)
    }


    // MARK: - nvALT routes, for compatibility

    func NvALTRouter(_ url: URL) {
        guard let directive = url.host else { return }

        switch directive {
        case NvALTRoutes.find.rawValue:
            RouteNvAltFind(url)
        case NvALTRoutes.make.rawValue:
            RouteNvAltMake(url)
        default:
            RouteNvAltBlank(url)
            break
        }
    }

    /// Handle URLs in the format nv://find/note%20title
    ///
    /// Note: this route is identical to the corresponding FSNotes route.
    ///
    func RouteNvAltFind(_ url: URL) {
        RouteFSNotesFind(url)
    }

    /// Handle URLs in the format nv://note%20title
    ///
    /// Note: this route is an alias to the /find route above.
    ///
    func RouteNvAltBlank(_ url: URL) {
        let pathWithFind = url.absoluteString.replacingOccurrences(of: "://", with: "://find/")
        guard let newURL = URL(string: pathWithFind) else { return }

        RouteFSNotesFind(newURL)
    }

    /// Handle URLs in the format:
    ///
    ///   - nv://make/?title=URI-escaped-title&html=URI-escaped-HTML-data&tags=URI-escaped-tag-string
    ///   - nv://make/?title=URI-escaped-title&txt=URI-escaped-plain-text
    ///   - nv://make/?txt=URI-escaped-plain-text
    ///
    /// The four possible parameters (title, txt, html and tags) are all optional.
    ///
    func RouteNvAltMake(_ url: URL) {
        var title = ""
        var body = ""

        if let titleParam = url["title"] {
            title = titleParam
        }

        if let txtParam = url["txt"] {
            body = txtParam
        }
        else if let htmlParam = url["html"] {
            body = htmlParam
        }

        if let tagsParam = url["tags"] {
            body = body.appending("\n\nnvALT tags: \(tagsParam)")
        }

        guard let window = NSApplication.shared.windows.first,
            let controller = window.contentViewController as? ViewController
            else { return }

        controller.createNote(name: title, content: body)
    }
}
