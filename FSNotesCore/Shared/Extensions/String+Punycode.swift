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

        let parts = host.components(separatedBy: ".")
        let domain = parts[0].idnaEncoded!
        let tld = parts[1].idnaEncoded!

        let unwrappedPath = path?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let result = String("\(scheme)://\(domain).\(tld)/\(unwrappedPath)")

        return result
    }
}
