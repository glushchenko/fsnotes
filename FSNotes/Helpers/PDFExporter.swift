//
//  PDFExporter.swift
//  FSNotes
//
//  Created for FSNotes share feature.
//

import WebKit

@available(macOS 11.0, *)
class PDFExporter: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private var indexURL: URL
    private var outputURL: URL
    private var completion: (URL?) -> Void
    private var webView: WKWebView?

    init(indexURL: URL, outputURL: URL, completion: @escaping (URL?) -> Void) {
        self.indexURL = indexURL
        self.outputURL = outputURL
        self.completion = completion
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "contentLoaded" else { return }

        // Measure the full document height and resize the web view before creating PDF.
        // createPDF only captures what fits in the web view's frame, so we need the
        // frame tall enough to contain all content for proper multi-page pagination.
        webView?.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
            guard let self = self, let height = result as? CGFloat else {
                self?.completion(nil)
                return
            }

            let pageWidth: CGFloat = 595.28
            self.webView?.frame = NSRect(x: 0, y: 0, width: pageWidth, height: max(height, 842))

            // Give WebKit a moment to re-layout at the new size
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let config = WKPDFConfiguration()
                // Don't set config.rect — let createPDF capture the entire web view
                // and paginate automatically based on A4 page height

                self.webView?.createPDF(configuration: config) { [weak self] pdfResult in
                    guard let self = self else { return }
                    switch pdfResult {
                    case .success(let data):
                        do {
                            try data.write(to: self.outputURL)
                            DispatchQueue.main.async {
                                self.completion(self.outputURL)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.completion(nil)
                            }
                        }
                    case .failure:
                        DispatchQueue.main.async {
                            self.completion(nil)
                        }
                    }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let script = """
        function checkIfComplete() {
            if (document.readyState === 'complete') {
                window.webkit.messageHandlers.contentLoaded.postMessage("contentLoaded");
            } else {
                setTimeout(checkIfComplete, 100);
            }
        }
        checkIfComplete();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    public func export() {
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
