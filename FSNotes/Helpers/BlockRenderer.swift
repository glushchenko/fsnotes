//
//  BlockRenderer.swift
//  FSNotes
//
//  Renders mermaid diagrams and LaTeX math to NSImage using a hidden WKWebView.
//

import WebKit

class BlockRenderer: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

    enum BlockType {
        case mermaid
        case math
    }

    private var webView: WKWebView?
    private var completion: ((NSImage?) -> Void)?
    private var blockType: BlockType = .mermaid
    private var tempFile: URL?

    // Cache rendered images by source hash
    private static var cache = NSCache<NSString, NSImage>()

    // Keep strong references to active renderers so they aren't deallocated
    // while the WKWebView is still loading (navigationDelegate is weak)
    private static var activeRenderers = Set<BlockRenderer>()

    static func render(source: String, type: BlockType, maxWidth: CGFloat = 480, completion: @escaping (NSImage?) -> Void) {
        let cacheKey = "\(type):\(source)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            NSLog("[BlockRenderer] Cache hit for \(type)")
            completion(cached)
            return
        }

        NSLog("[BlockRenderer] Starting render for \(type), source length: \(source.count)")
        let renderer = BlockRenderer()
        renderer.blockType = type
        renderer.completion = { [weak renderer] image in
            NSLog("[BlockRenderer] Completion called, image: \(image != nil ? "YES \(image!.size)" : "nil")")
            if let image = image {
                cache.setObject(image, forKey: cacheKey)
            }
            completion(image)
            if let renderer = renderer {
                activeRenderers.remove(renderer)
            }
        }
        activeRenderers.insert(renderer)
        renderer.startRender(source: source, type: type, maxWidth: maxWidth)
    }

    private func startRender(source: String, type: BlockType, maxWidth: CGFloat) {
        let contentController = WKUserContentController()
        contentController.add(self, name: "renderComplete")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: maxWidth, height: 100), configuration: config)
        webView?.navigationDelegate = self
        // Make WKWebView background transparent so snapshot has no opaque fill
        webView?.setValue(false, forKey: "drawsBackground")

        guard let bundleURL = Bundle.main.url(forResource: "MPreview", withExtension: "bundle") else {
            NSLog("[BlockRenderer] ERROR: MPreview.bundle not found")
            completion?(nil)
            return
        }
        NSLog("[BlockRenderer] Bundle URL: \(bundleURL.path)")

        let html = generateHTML(source: source, type: type, maxWidth: maxWidth)

        // Write HTML to a temp file inside the bundle directory so loadFileURL
        // can access both the HTML and the JS files with a single access grant
        let tempFile = bundleURL.appendingPathComponent("_render_\(UUID().uuidString).html")
        do {
            try html.write(to: tempFile, atomically: true, encoding: .utf8)
            self.tempFile = tempFile
            NSLog("[BlockRenderer] Loading temp file: \(tempFile.path)")
            webView?.loadFileURL(tempFile, allowingReadAccessTo: bundleURL)
        } catch {
            NSLog("[BlockRenderer] ERROR writing temp file: \(error)")
            completion?(nil)
        }
    }

    private func generateHTML(source: String, type: BlockType, maxWidth: CGFloat) -> String {
        let escapedSource = source
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let textColor = isDark ? "#d4d4d4" : "#333333"
        let mermaidTheme = isDark ? "dark" : "default"

        switch type {
        case .mermaid:
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <style>
                    body { margin: 0; padding: 0; background: transparent; color: \(textColor); }
                    .mermaid { max-width: \(Int(maxWidth))px; }
                    svg { max-width: 100%; }
                </style>
                <script src="js/mermaid.min.js"></script>
            </head>
            <body>
                <pre class="mermaid">\(escapedSource)</pre>
                <script>
                    mermaid.initialize({ startOnLoad: false, theme: '\(mermaidTheme)', flowchart: { useMaxWidth: true, htmlLabels: true } });
                    mermaid.run().then(function() {
                        setTimeout(function() {
                            var svg = document.querySelector('.mermaid svg');
                            if (svg) {
                                // Expand the SVG viewBox by 2px on each side to include stroke overflow
                                var vb = svg.viewBox.baseVal;
                                if (vb && vb.width > 0) {
                                    svg.setAttribute('viewBox',
                                        (vb.x - 2) + ' ' + (vb.y - 2) + ' ' +
                                        (vb.width + 4) + ' ' + (vb.height + 4));
                                }
                            }
                            var el = svg || document.querySelector('.mermaid');
                            var rect = el.getBoundingClientRect();
                            window.webkit.messageHandlers.renderComplete.postMessage({
                                width: Math.ceil(rect.width),
                                height: Math.ceil(rect.height)
                            });
                        }, 200);
                    }).catch(function(e) {
                        window.webkit.messageHandlers.renderComplete.postMessage({ error: e.toString() });
                    });
                </script>
            </body>
            </html>
            """

        case .math:
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <style>
                    body { margin: 0; padding: 0; background: transparent; color: \(textColor); }
                </style>
                <script src="js/tex-mml-chtml.js"></script>
            </head>
            <body>
                <div id="math">$$\(escapedSource)$$</div>
                <script>
                    MathJax.startup.promise.then(function() {
                        MathJax.typeset();
                        setTimeout(function() {
                            var el = document.getElementById('math');
                            var rect = el.getBoundingClientRect();
                            window.webkit.messageHandlers.renderComplete.postMessage({
                                width: Math.ceil(rect.width),
                                height: Math.ceil(rect.height)
                            });
                        }, 200);
                    });
                </script>
            </body>
            </html>
            """
        }
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        NSLog("[BlockRenderer] Message received: \(message.name) body: \(message.body)")
        guard message.name == "renderComplete",
              let body = message.body as? [String: Any] else {
            NSLog("[BlockRenderer] ERROR: unexpected message format")
            completion?(nil)
            return
        }

        if let error = body["error"] {
            NSLog("[BlockRenderer] ERROR from JS: \(error)")
            completion?(nil)
            return
        }

        guard let width = body["width"] as? CGFloat,
              let height = body["height"] as? CGFloat,
              width > 0, height > 0 else {
            completion?(nil)
            return
        }

        // Resize webview to exact content size and take snapshot
        webView?.frame = NSRect(x: 0, y: 0, width: width, height: height)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let webView = self?.webView else {
                self?.completion?(nil)
                return
            }

            let snapshotConfig = WKSnapshotConfiguration()
            snapshotConfig.rect = NSRect(x: 0, y: 0, width: width, height: height)
            snapshotConfig.afterScreenUpdates = true

            webView.takeSnapshot(with: snapshotConfig) { [weak self] image, error in
                DispatchQueue.main.async {
                    self?.completion?(image)
                    self?.cleanup()
                }
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("[BlockRenderer] Navigation finished successfully")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[BlockRenderer] Navigation FAILED: \(error)")
        completion?(nil)
        cleanup()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("[BlockRenderer] Provisional navigation FAILED: \(error)")
        completion?(nil)
        cleanup()
    }

    private func cleanup() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "renderComplete")
        webView?.navigationDelegate = nil
        webView = nil
        if let tempFile = tempFile {
            try? FileManager.default.removeItem(at: tempFile)
        }
        tempFile = nil
        BlockRenderer.activeRenderers.remove(self)
    }
}
