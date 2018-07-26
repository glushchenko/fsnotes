//
//  Note+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

extension Note {
    public override func data(ofType typeName: String) throws -> Data {
        let range = NSRange(0..<self.content.length)
        let data = try self.content.data(from: range, documentAttributes: self.getDocAttributes())

        return data
    }
}
