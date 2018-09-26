//
//  UINote.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/13/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class UINote: UIDocument {
    private var textWrapper: FileWrapper

    init(fileURL: URL, textWrapper: FileWrapper) {
        self.textWrapper = textWrapper

        super.init(fileURL: fileURL)
    }

    public override func contents(forType typeName: String) throws -> Any {
        return self.textWrapper
    }

    public override func load(fromContents contents: Any, ofType typeName: String?) throws {
    }
}
