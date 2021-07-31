//
//  ViewController+Print.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 2/15/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import WebKit

extension ViewController {

    @objc func allImagesLoaded(_ message: String) {}

    override class func isSelectorExcluded(fromWebScript sel: Selector) -> Bool {
        if sel == #selector(ViewController.allImagesLoaded(_:)) {
            return false
        }
        return true
    }

    override class func webScriptName(for sel: Selector) -> String? {
        if sel == #selector(ViewController.allImagesLoaded(_:)) {
            return "allImagesLoaded";
        }
        return nil
    }

    public func printMarkdownPreview(webView: WebView?) {
        guard let note = EditTextView.note else { return }

        let classBundle = Bundle(for: MPreviewView.self)
        let url = classBundle.url(forResource: "DownView", withExtension: "bundle")!
        let bundle = Bundle(url: url)!
        let baseURL = bundle.url(forResource: "index", withExtension: "html")!

        let markdownString = note.getPrettifiedContent()
        let css = MPreviewView.getPreviewStyle(theme: "atom-one-light", fullScreen: true, useFixedImageHeight: false) + "  .copyCode { display: none; } body { -webkit-text-size-adjust: none; font-size: 1.0em;} pre, code { border: 1px solid #c0c4ce; border-radius: 3px; } pre, pre code { word-wrap: break-word; }";

        var template = try! NSString(contentsOf: baseURL, encoding: String.Encoding.utf8.rawValue)
        template = template.replacingOccurrences(of: "DOWN_CSS", with: css) as NSString

        let html = renderMarkdownHTML(markdown: markdownString)!
        var htmlString = template.replacingOccurrences(of: "DOWN_HTML", with: html)

        htmlString = htmlString.replacingOccurrences(of: "MATH_JAX_JS", with: MPreviewView.getMathJaxJS())

        let printDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Print")
        try? FileManager.default.removeItem(at: printDir)

        copyInitialFiles(printDir: printDir)
        copyImages(note: note, dst: printDir)

        webView?.frameLoadDelegate = self
        webView?.mainFrame.loadHTMLString(htmlString, baseURL: printDir)

        if UserDataService.instance.isDark {
            webView?.stringByEvaluatingJavaScript(from: "switchToDarkMode();")
        }
    }

    public func copyInitialFiles(printDir: URL) {
        let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
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

        let downJS = printDir.appendingPathComponent("js/down.js")

        if !FileManager.default.fileExists(atPath: downJS.path) {
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
    }

    public func copyImages(note: Note, dst: URL) {
        NotesTextProcessor.imageInlineRegex.regularExpression.enumerateMatches(in: note.content.string, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(0..<note.content.length), using:
                {(result, flags, stop) -> Void in

            guard let range = result?.range(at: 3), note.content.length >= range.location else { return }

            guard let imagePath = note.content.attributedSubstring(from: range).string.removingPercentEncoding else { return }

            if let url = note.getImageUrl(imageName: imagePath) {
                if url.isRemote() {
                    return
                }

                if FileManager.default.fileExists(atPath: url.path), url.isImage {
                    let result = dst.appendingPathComponent(imagePath)
                    let dstDir = result.deletingLastPathComponent()

                    try? FileManager.default.createDirectory(at:dstDir, withIntermediateDirectories: true, attributes: nil)

                    try? FileManager.default.copyItem(at: url, to: result)
                }
            }
        })

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
