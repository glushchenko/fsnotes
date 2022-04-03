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
}
