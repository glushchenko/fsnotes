//
//  Data+.swift
//  FSNotes
//
//  Created by Александр on 03.04.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension Data {
    var isPDF: Bool {
        guard self.count >= 1024 else { return false }
        let pdfHeader = Data(bytes: "%PDF", count: 4)
        return self.range(of: pdfHeader, options: [], in: Range(NSRange(location: 0, length: 1024))) != nil
    }

    mutating func append(_ string: String, using encoding: String.Encoding = .utf8) {
        if let data = string.data(using: encoding) {
            append(data)
        }
    }

    func getFileType() -> ImageFormat {
        switch self[0] {
        case 0x89:
            return .png
        case 0xFF:
            return .jpg
        case 0x47:
            return .gif
        case 0x49, 0x4D:
            return .tiff
        case 0x52 where self.count >= 12:
            let subdata = self[0...11]

            if let dataString = String(data: subdata, encoding: .ascii),
                dataString.hasPrefix("RIFF"),
                dataString.hasSuffix("WEBP")
            {
                return .webp
            }

        case 0x00 where self.count >= 12 :
            let subdata = self[8...11]

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
}
