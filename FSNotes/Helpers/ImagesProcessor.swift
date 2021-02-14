//
//  ImagesProcessor.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 1/12/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public class ImagesProcessor {
    
    public static func getFileName(from: URL? = nil, to: URL, ext: String? = nil) -> String? {
        let path = from?.absoluteString ?? to.absoluteString
        var name: String?

        if path.starts(with: "http://") || path.starts(with: "https://"), let webName = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            name = webName
        }
        
        if path.starts(with: "file://") {
            var ext = ext ?? "jpg"
            var pathComponent = NSUUID().uuidString.lowercased() + "." + ext

            if let from = from {
                pathComponent = from.lastPathComponent
                ext = from.pathExtension
            }

            while name == nil {
                let destination = to.appendingPathComponent(pathComponent)
                let icloud = destination.appendingPathExtension("icloud")
                
                if FileManager.default.fileExists(atPath: destination.path) || FileManager.default.fileExists(atPath: icloud.path) {
                    pathComponent = NSUUID().uuidString.lowercased() + ".\(ext)"
                    continue
                }
                
                name = pathComponent
            }
        }

        return name
    }
    
    public static func writeFile(data: Data, url: URL? = nil, note: Note, ext: String? = nil) -> String? {
        if note.isTextBundle() {
            let assetsUrl = note.getURL().appendingPathComponent("assets")
            
            if !FileManager.default.fileExists(atPath: assetsUrl.path, isDirectory: nil) {
                try? FileManager.default.createDirectory(at: assetsUrl, withIntermediateDirectories: true, attributes: nil)
            }

            let destination = URL(fileURLWithPath: assetsUrl.path)
            guard var fileName = ImagesProcessor.getFileName(from: url, to: destination, ext: ext) else { return nil }
            
            let to = destination.appendingPathComponent(fileName)
            do {
                try data.write(to: to, options: .atomic)
            } catch {
                print(error)
            }

            fileName = fileName
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName

            return "assets/\(fileName)"
        }

        var prefix = "i/"
        if let url = url, !url.isImage {
            prefix = "files/"
        }

        let project = note.project
        let destination = URL(fileURLWithPath: project.url.path + "/" + prefix)

        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false, attributes: nil)
        } catch {}

        guard var fileName = ImagesProcessor.getFileName(from: url, to: destination, ext: ext) else { return nil }

        let to = destination.appendingPathComponent(fileName)
        try? data.write(to: to, options: .atomic)

        fileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName

        return "\(prefix)\(fileName)"
    }
}
