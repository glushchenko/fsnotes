//
//  ImageFormat.swift
//  FSNotes iOS
//
//  Created by Олександр Глущенко on 08.06.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

enum ImageFormat: String {
    case png, jpg, gif, tiff, webp, heic, unknown
}

extension ImageFormat {
    static func get(from data: Data) -> ImageFormat {
        switch data[0] {
        case 0x89:
            return .png
        case 0xFF:
            return .jpg
        case 0x47:
            return .gif
        case 0x49, 0x4D:
            return .tiff
        case 0x52 where data.count >= 12:
            let subdata = data[0...11]

            if let dataString = String(data: subdata, encoding: .ascii),
                dataString.hasPrefix("RIFF"),
                dataString.hasSuffix("WEBP")
            {
                return .webp
            }

        case 0x00 where data.count >= 12 :
            let subdata = data[8...11]

            if let dataString = String(data: subdata, encoding: .ascii),
                Set(["heic", "heix", "hevc", "hevx"]).contains(dataString)
                ///OLD: "ftypheic", "ftypheix", "ftyphevc", "ftyphevx"
            {
                return .heic
            }
        default:
            break
        }
        return .unknown
    }

    var contentType: String {
        return "image/\(rawValue)"
    }
}
