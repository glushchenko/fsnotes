//
//  ViewController+Print.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 2/15/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import WebKit

extension EditorViewController {

    public func printMarkdownPreview() {
        guard let note = vcEditor?.note else { return }

        let printDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Print")
        try? FileManager.default.removeItem(at: printDir)
        
        guard let indexURL = MPreviewView.buildPage(for: note, at: printDir, print: true) else { return }

        if #available(macOS 11.0, *) {
            let pdfCreator = Printer(indexURL: indexURL)
            pdfCreator.printWeb()
        } else {
            legacyPrint(indexURL: indexURL)
        }
    }

    @available(*, deprecated, message: "Remove after macOS 10.15 is no longer supported")
    public func legacyPrint(indexURL: URL) {
        guard let vc = ViewController.shared() else { return }

        vc.printerLegacy = PrinterLegacy(indexURL: indexURL)
        vc.printerLegacy?.printWeb()
    }
}
