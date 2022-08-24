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

        let classBundle = Bundle(for: MPreviewView.self)
        let url = classBundle.url(forResource: "MPreview", withExtension: "bundle")!
        let bundle = Bundle(url: url)!
        let baseURL = bundle.url(forResource: "index", withExtension: "html")!

        let cssURL = bundle.url(forResource: "main", withExtension: "css")!
        var css = try! String(contentsOf: cssURL)
        let markdownString = note.getPrettifiedContent()

        css += MPreviewView.getPreviewStyle(theme: "github", fullScreen: true, useFixedImageHeight: false) + "  .copyCode { display: none; } body { -webkit-text-size-adjust: none; font-size: 1.0em;} pre, code { border: 1px solid #c0c4ce; border-radius: 3px; } pre, pre code { word-wrap: break-word; }";

        let template = try! NSString(contentsOf: baseURL, encoding: String.Encoding.utf8.rawValue)
    
        let html = renderMarkdownHTML(markdown: markdownString)!
        var htmlString = template
            .replacingOccurrences(of: "{INLINE_CSS}", with: css)
            .replacingOccurrences(of: "{NOTE_BODY}", with: html)
            .replacingOccurrences(of: "{MATH_JAX_JS}", with: MPreviewView.getMathJaxJS())
            .replacingOccurrences(of: "{WEB_PATH}", with: String())
            

        let printDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Print")
        try? FileManager.default.removeItem(at: printDir)

        copyInitialFiles(printDir: printDir)
        htmlString = assignBase64Images(note: note, html: htmlString)

        self.printWebView.frameLoadDelegate = self
        self.printWebView.mainFrame.loadHTMLString(htmlString, baseURL: printDir)

        if UserDataService.instance.isDark {
            self.printWebView.stringByEvaluatingJavaScript(from: "switchToDarkMode();")
        }
    }

    public func copyInitialFiles(printDir: URL) {
        let path = Bundle.main.path(forResource: "MPreview", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)

        guard let bundleResourceURL = bundle?.resourceURL
            else { return }

        if !FileManager.default.fileExists(atPath: printDir.path) {
            do {
                try FileManager.default.createDirectory(at: printDir, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print(error)
            }
        }

        do {
            let fileList = try FileManager.default.contentsOfDirectory(atPath: bundleResourceURL.path)

            for file in fileList {
                let tmpURL = printDir.appendingPathComponent(file)
                try? FileManager.default.copyItem(atPath: bundleResourceURL.appendingPathComponent(file).path, toPath: tmpURL.path)
            }
        } catch {
            print(error)
        }
    }

    public func assignBase64Images(note: Note, html: String) -> String {
        var html = html

        FSParser.imageInlineRegex.regularExpression.enumerateMatches(in: note.content.string, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(0..<note.content.length), using:
                {(result, flags, stop) -> Void in

            guard let range = result?.range(at: 3), note.content.length >= range.location else { return }

            let path = note.content.attributedSubstring(from: range).string
            guard let imagePath = path.removingPercentEncoding else { return }

            if let url = note.getImageUrl(imageName: imagePath) {
                if url.isRemote() {
                    return
                }

                if FileManager.default.fileExists(atPath: url.path), url.isImage {
                    if let image = try? Data(contentsOf: url) {
                        let base64 = image.base64EncodedString()
                        html = html.replacingOccurrences(of: path, with: "data:image;base64," + base64)
                    }
                }
            }
        })

        return html
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
