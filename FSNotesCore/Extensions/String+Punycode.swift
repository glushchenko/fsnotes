//
//  String+Punycode.swift
//  FSNotes
//
//  Created by Александр on 30.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Punycode

extension String {
    func idnaEncodeURL() -> String {
        if URL(string: self) != nil {
            return self
        }

        var scheme: String?
        var host: String?
        var path: String?
        var url = self

        if url.startsWith(string: "https://") {
            url = String(url.dropFirst(8))
            scheme = "https"
        }

        if url.startsWith(string: "http://") {
            url = String(url.dropFirst(7))
            scheme = "http"
        }

        guard let scheme = scheme else { return self }

        if url.contains("/") {
            let parts = url.components(separatedBy: "/")
            if parts[0].contains(".") {
                host = parts[0]
                path = parts.dropFirst().joined(separator: "/")
            }
        } else if url.contains(".") {
            host = url
        }

        guard let host = host else { return self }

        let parts = host.components(separatedBy: ".").compactMap({ $0.idnaEncoded! })
        let domain = parts.joined(separator: ".")

        let encodedPath = getEncodedPath(path: path)
        let result = String("\(scheme)://\(domain)/\(encodedPath)")

        return result
    }

    private func getEncodedPath(path: String?) -> String {
        var unwrappedPath = String()

        if let path = path {
            var addPercentEncoding = false
            for pathChar in path.unicodeScalars {
                if !CharacterSet.urlPathAllowed.contains(pathChar) {
                    addPercentEncoding = true
                }
            }

            if addPercentEncoding, let pathPercentEncoded = path.removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                unwrappedPath = pathPercentEncoded
            } else {
                unwrappedPath = path
            }
        }

        return unwrappedPath
    }
}
