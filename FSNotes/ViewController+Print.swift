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
        
        guard let indexURL = MPreviewView.buildPage(for: note, at: printDir, print: true),
              let content = try? String(contentsOf: indexURL) else { return }
    
        self.printWebView.frameLoadDelegate = self
        self.printWebView.mainFrame.loadHTMLString(content, baseURL: printDir)

        if UserDataService.instance.isDark {
            self.printWebView.stringByEvaluatingJavaScript(from: "switchToDarkMode();")
        }
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
}
