//
//  PrinterLegacy.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 08.08.2024.
//  Copyright © 2024 Oleksandr Hlushchenko. All rights reserved.
//

import WebKit

@available(*, deprecated, message: "Remove after macOS 10.15 is no longer supported")
class PrinterLegacy: NSObject, WebFrameLoadDelegate {
    private var indexURL: URL
    private var pop: NSPrintOperation?
    public var printWebView = WebView()

    init(indexURL: URL) {
        self.indexURL = indexURL
        super.init()
    }


    func webView(_ sender: WebView!, didFinishLoadFor frame: WebFrame!) {
        if sender.isLoading {
            return
        }
        if frame != sender.mainFrame {
            return
        }
        if sender.stringByEvaluatingJavaScript(from: "document.readyState") == "complete" {
            sender.frameLoadDelegate = nil

            let printInfo = NSPrintInfo.shared
            printInfo.paperSize = NSMakeSize(595.22, 841.85)
            printInfo.topMargin = 40.0
            printInfo.leftMargin = 40.0
            printInfo.rightMargin = 40.0
            printInfo.bottomMargin = 40.0

            let when = DispatchTime.now() + 0.2
            DispatchQueue.main.asyncAfter(deadline: when) {
                let operation: NSPrintOperation = NSPrintOperation(view: sender.mainFrame.frameView.documentView, printInfo: printInfo)
                operation.printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
                operation.printPanel.options.insert(NSPrintPanel.Options.showsOrientation)
                operation.run()
            }
        }
    }

   public func printWeb() {
       let printDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Print")

       guard let content = try? String(contentsOf: indexURL) else { return }

       self.printWebView.frameLoadDelegate = self
       self.printWebView.frame = NSRect(x: 0, y: 0, width: 800.0, height: 500.0)
       self.printWebView.mainFrame.loadHTMLString(content, baseURL: printDir)
    }
}
