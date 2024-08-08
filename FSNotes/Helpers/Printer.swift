//
//  Printer.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 08.08.2024.
//  Copyright © 2024 Oleksandr Hlushchenko. All rights reserved.
//

import WebKit

@available(macOS 11.0, *)
class Printer: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private var indexURL: URL
    private var pop: NSPrintOperation?
    private var webView: WKWebView?

    init(indexURL: URL) {
        self.indexURL = indexURL
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        guard message.name == "contentLoaded" else { return }

        let printInfo = NSPrintInfo(dictionary: [.paperSize: CGSize(width: 595.28, height: 841.89)])
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        let margin = 20.0
        printInfo.leftMargin = margin
        printInfo.topMargin = margin
        printInfo.rightMargin = margin
        printInfo.bottomMargin = margin
        printInfo.isVerticallyCentered = true
        printInfo.isHorizontallyCentered = true

        self.pop = self.webView?.printOperation(with: printInfo)
        self.pop?.printPanel.options.insert(.showsPaperSize)
        self.pop?.printPanel.options.insert(.showsOrientation)
        self.pop?.printPanel.options.insert(.showsPreview)

        self.pop?.showsPrintPanel = true
        self.pop?.showsProgressPanel = true
        self.pop?.view?.frame = NSRect(x: 0, y: 0, width: 800.0, height: 500.0)

        DispatchQueue.main.async {
            let window = NSApplication.shared.mainWindow
            //let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)

            self.pop?.runModal(for: window!, delegate: nil, didRun: nil, contextInfo: nil)
        }

    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let checkContentLoadedScript = """
        function checkIfComplete() {
            if (document.readyState === 'complete') {
                window.webkit.messageHandlers.contentLoaded.postMessage("contentLoaded");
            } else {
                setTimeout(checkIfComplete, 100);
            }
        }
        checkIfComplete();
        """

        webView.evaluateJavaScript(checkContentLoadedScript, completionHandler: nil)
    }

    public func printWeb() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "contentLoaded")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 595, height: 842), configuration: config)
        webView?.navigationDelegate = self

        let accessURL = indexURL.deletingLastPathComponent()
        webView?.loadFileURL(indexURL, allowingReadAccessTo: accessURL)
    }
}
