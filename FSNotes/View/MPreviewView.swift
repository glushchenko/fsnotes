//
//  MPreviewView.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 8/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import WebKit
import Highlightr

#if os(iOS)
import NightNight
import MobileCoreServices
import AudioToolbox
#else
import Carbon.HIToolbox
#endif

public typealias MPreviewViewClosure = () -> ()

class MPreviewView: WKWebView, WKUIDelegate, WKNavigationDelegate {

    private weak var note: Note?
    private var closure: MPreviewViewClosure?
    public static var template: String?
    
    init(frame: CGRect, note: Note, closure: MPreviewViewClosure?, force: Bool = false) {
        self.closure = closure
        let userContentController = WKUserContentController()
        userContentController.add(HandlerSelection(), name: "newSelectionDetected")
        userContentController.add(HandlerCheckbox(), name: "checkbox")
        userContentController.add(HandlerMouse(), name: "mouse")
        userContentController.add(HandlerClipboard(), name: "clipboard")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.suppressesIncrementalRendering = true
        
        super.init(frame: frame, configuration: configuration)

        navigationDelegate = self
        
#if os(OSX)
        if #available(macOS 10.14, *) {
              setValue(false, forKey: "drawsBackground")
        }
#else
        isOpaque = false
        backgroundColor = UIColor.clear
        scrollView.backgroundColor = UIColor.clear
        scrollView.bounces = true
#endif

        load(note: note, force: force)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

#if os(OSX)
    override func mouseDown(with event: NSEvent) {
        if let note = EditTextView.note, let vc = ViewController.shared() {
            if note.container == .encryptedTextPack && !note.isUnlocked() {
                vc.unLock(notes: [note])
            } else if note.content.length == 0 {
                vc.currentPreviewState = .off
                vc.refillEditArea()
                vc.focusEditArea()
            }
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Return {
            DispatchQueue.main.async {
                guard let vc = ViewController.shared() else { return }
                vc.currentPreviewState = .off
                vc.refillEditArea()
                vc.focusEditArea()
            }
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.characters?.unicodeScalars.first == "c" && event.modifierFlags.contains(.command) {
            DispatchQueue.main.async {
                guard let string = HandlerSelection.selectionString else { return }
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(string, forType: NSPasteboard.PasteboardType.string)
            }

            return false
        }

        return super.performKeyEquivalent(with: event)
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        for item in menu.items {
            if item.identifier?.rawValue == "WKMenuItemIdentifierReload" {
                item.isHidden = true
            }
        }
    }
#endif

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        closure?()
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return }

        switch navigationAction.navigationType {
        case .linkActivated:
            decisionHandler(.cancel)

            if isFootNotes(url: url) {
                return
            }

#if os(iOS)
            if url.absoluteString.starts(with: "fsnotes://find?id=") {
                UIApplication.getEVC().openWikiLink(query: url.absoluteString)
                return
            }

            UIApplication.shared.open(url, options: [:], completionHandler: nil)
#elseif os(OSX)
            NSWorkspace.shared.open(url)
#endif
        default:
            decisionHandler(.allow)
        }
    }

    public func load(note: Note, force: Bool = false) {
        /// Do not re-load already loaded view
        guard self.note != note || force else { return }
        
        let markdownString = note.getPrettifiedContent()
        let css = MPreviewView.getPreviewStyle()

        var imagesStorage = note.project.url
        if note.isTextBundle() {
            imagesStorage = note.getURL()
        }

        if let urls = note.imageUrl, urls.count > 0 {
            cleanCache()
            try? loadHTMLView(markdownString, css: css, imagesStorage: imagesStorage)
        } else {
            fastLoading(note: note, markdown: markdownString, css: css)
        }
        
        self.note = note
    }

    public func cleanCache() {
        URLCache.shared.removeAllCachedResponses()

        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
            }
        }
    }

    public func fastLoading(note: Note, markdown: String, css: String) {
        if MPreviewView.template == nil {
            MPreviewView.template = getTemplate(css: css)
        }

        let template = MPreviewView.template
        let htmlString = renderMarkdownHTML(markdown: markdown)!

        guard var pageHTMLString = template?.replacingOccurrences(of: "DOWN_HTML", with: htmlString) else { return }

        var baseURL: URL?
        if let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle") {
            let url = NSURL.fileURL(withPath: path)
            if let bundle = Bundle(url: url) {
                baseURL = bundle.url(forResource: "index", withExtension: "html")
            }
        }

        pageHTMLString = pageHTMLString.replacingOccurrences(of: "MATH_JAX_JS", with: MPreviewView.getMathJaxJS())

        loadHTMLString(pageHTMLString, baseURL: baseURL)
    }

    public static func getMathJaxJS() -> String {
        if !UserDefaultsManagement.mathJaxPreview {
            return String()
        }

    #if os(OSX)
        let inline = "['$', '$'], ['$$', '$$'], ['\\((', '\\))']"
    #else
        let inline = "['$$', '$$'], ['\\((', '\\))']"
    #endif

        return """
            <script src="js/MathJax-2.7.5/MathJax.js?config=TeX-MML-AM_CHTML" async></script>
            <script type="text/x-mathjax-config">
                MathJax.Hub.Config({ showMathMenu: false, tex2jax: {
                    inlineMath: [ \(inline) ],
                }, messageStyle: "none", showProcessingMessages: true });
            </script>
        """
    }

    private func getTemplate(css: String) -> String? {
        var css = css

        #if os(OSX)
            let tagColor = NSColor.tagColor.hexString
            css += " a[href^=\"fsnotes://open/?tag=\"] { background: \(tagColor); }"
        #else
            css += " a[href^=\"fsnotes://open/?tag=\"] { background: #6692cb; }"
        #endif

        let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)
        let baseURL = bundle!.url(forResource: "index", withExtension: "html")!

        guard var template = try? NSString(contentsOf: baseURL, encoding: String.Encoding.utf8.rawValue) else { return nil }
        template = template.replacingOccurrences(of: "DOWN_CSS", with: css) as NSString

        var platform = String()

#if os(iOS)
        platform = "ios"

        if NightNight.theme == .night {
            template =
                template
                    .replacingOccurrences(of: "CUSTOM_CSS", with: "darkmode")
                    .replacingOccurrences(of: "IS_IOS", with: "true") as NSString
        }
#else
        platform = "macos"

        if UserDataService.instance.isDark {
            template = template.replacingOccurrences(of: "CUSTOM_CSS", with: "darkmode") as NSString
        }
#endif

        template = template.replacingOccurrences(of: "T_PLATFORM", with: platform) as NSString

        return template as String
    }

    private func isFootNotes(url: URL) -> Bool {
        let link = url.absoluteString.components(separatedBy: "/index.html#")
        if link.count == 2 {
            let anchor = link[1]

            evaluateJavaScript("document.getElementById('\(anchor)').offsetTop") { [weak self] (result, error) in
                if let offset = result as? CGFloat {
                    self?.evaluateJavaScript("window.scrollTo(0,\(offset))", completionHandler: nil)
                }
            }

            evaluateJavaScript("getElementsByText('\(anchor)')[0].offsetTop") { [weak self] (result, error) in
                if let offset = result as? CGFloat {
                    self?.evaluateJavaScript("window.scrollTo(0,\(offset))", completionHandler: nil)
                }
            }
            
            let textQuery = anchor.replacingOccurrences(of: "-", with: " ")
            evaluateJavaScript("getElementsByTextContent('\(textQuery)').offsetTop") { [weak self] (result, error) in
                if let offset = result as? CGFloat {
                    self?.evaluateJavaScript("window.scrollTo(0,\(offset))", completionHandler: nil)
                }
            }

            return true
        }

        return false
    }

    func loadHTMLView(_ markdownString: String, css: String, imagesStorage: URL? = nil) throws {
        var htmlString = renderMarkdownHTML(markdown: markdownString)!

        if let imagesStorage = imagesStorage {
            htmlString = loadImages(imagesStorage: imagesStorage, html: htmlString)
        }

        let pageHTMLString = try htmlFromTemplate(htmlString, css: css)
        let indexURL = createTemporaryBundle(pageHTMLString: pageHTMLString)

        if let i = indexURL {
            let accessURL = i.deletingLastPathComponent()
            loadFileURL(i, allowingReadAccessTo: accessURL)
        }
    }

    func createTemporaryBundle(pageHTMLString: String) -> URL? {
        let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)

        guard let bundleResourceURL = bundle?.resourceURL
            else { return nil }

        let customCSS = UserDefaultsManagement.markdownPreviewCSS

        let webkitPreview = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wkPreview")

        try? FileManager.default.createDirectory(at: webkitPreview, withIntermediateDirectories: true, attributes: nil)

        let indexURL = webkitPreview.appendingPathComponent("index.html")
        let downJS = webkitPreview.appendingPathComponent("js/down.js")

        // If updating markdown contents, no need to re-copy bundle.
        if !FileManager.default.fileExists(atPath: indexURL.path)
            || !FileManager.default.fileExists(atPath: downJS.path)
        {
            // Copy bundle resources to temporary location.
            do {
                let fileList = try FileManager.default.contentsOfDirectory(atPath: bundleResourceURL.path)

                for file in fileList {
                    if customCSS != nil && file == "css" {
                        continue
                    }

                    let tmpURL = webkitPreview.appendingPathComponent(file)

                    if ["css", "js"].contains(file) {
                        try? FileManager.default.removeItem(at: tmpURL)
                    }

                    try? FileManager.default.copyItem(atPath: bundleResourceURL.appendingPathComponent(file).path, toPath: tmpURL.path)
                }
            } catch {
                print(error)
            }
        }

        if let customCSS = customCSS {
            let cssDst = webkitPreview.appendingPathComponent("css")
            let styleDst = cssDst.appendingPathComponent("markdown-preview.css", isDirectory: false)

            do {
                try FileManager.default.createDirectory(at: cssDst, withIntermediateDirectories: false, attributes: nil)
                _ = try FileManager.default.copyItem(at: customCSS, to: styleDst)
            } catch {
                print(error)
            }
        }

        // Write generated index.html to temporary location.
        try? pageHTMLString.write(to: indexURL, atomically: true, encoding: .utf8)

        return indexURL
    }

    private func loadImages(imagesStorage: URL, html: String) -> String {
        var htmlString = html

        do {
            let regex = try NSRegularExpression(pattern: "<img.*?src=\"([^\"]*)\"")
            let results = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

            let images = results.map {
                String(html[Range($0.range, in: html)!])
            }

            for image in images {
                var localPath = image.replacingOccurrences(of: "<img src=\"", with: "").dropLast()

                guard !localPath.starts(with: "http://") && !localPath.starts(with: "https://") else {
                    continue
                }

                let localPathClean = localPath.removingPercentEncoding ?? String(localPath)

                let fullImageURL = imagesStorage
                let imageURL = fullImageURL.appendingPathComponent(localPathClean)

                let webkitPreview = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wkPreview")

                let create = webkitPreview
                    .appendingPathComponent(localPathClean)
                    .deletingLastPathComponent()
                let destination = webkitPreview.appendingPathComponent(localPathClean)

                try? FileManager.default.createDirectory(atPath: create.path, withIntermediateDirectories: true, attributes: nil)
                try? FileManager.default.removeItem(at: destination)
                try? FileManager.default.copyItem(at: imageURL, to: destination)

                var orientation = 0
                let url = NSURL(fileURLWithPath: imageURL.path)
                if let imageSource = CGImageSourceCreateWithURL(url, nil) {
                    let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary?
                    if let orientationProp = imageProperties?[kCGImagePropertyOrientation] as? Int {
                        orientation = orientationProp
                    }
                }

                if localPath.first == "/" {
                    localPath.remove(at: localPath.startIndex)
                }

                let imPath = "<img data-orientation=\"\(orientation)\" class=\"fsnotes-preview\" src=\"" + localPath + "\""

                htmlString = htmlString.replacingOccurrences(of: image, with: imPath)
            }
        } catch let error {
            print("Images regex: \(error.localizedDescription)")
        }

        return htmlString
    }

    func htmlFromTemplate(_ htmlString: String, css: String) throws -> String {
        var css = css

        #if os(OSX)
            let tagColor = NSColor.tagColor.hexString
            css += " a[href^=\"fsnotes://open/?tag=\"] { background: \(tagColor); }"
        #else
            css += " a[href^=\"fsnotes://open/?tag=\"] { background: #6692cb; }"
        #endif

        let path = Bundle.main.path(forResource: "DownView", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)
        let baseURL = bundle!.url(forResource: "index", withExtension: "html")!

        var template = try NSString(contentsOf: baseURL, encoding: String.Encoding.utf8.rawValue)
        template = template.replacingOccurrences(of: "DOWN_CSS", with: css) as NSString

        var platform = String()

#if os(iOS)
        platform = "ios"

        if NightNight.theme == .night {
            template = template
                .replacingOccurrences(of: "CUSTOM_CSS", with: "darkmode")
                .replacingOccurrences(of: "IS_IOS", with: "true") as NSString
        }
#else
        platform = "macos"

        if UserDataService.instance.isDark {
            template = template.replacingOccurrences(of: "CUSTOM_CSS", with: "darkmode") as NSString
        }
#endif
        template = template
            .replacingOccurrences(of: "T_PLATFORM", with: platform)
            .replacingOccurrences(of: "MATH_JAX_JS", with: MPreviewView.getMathJaxJS()) as NSString

        return template.replacingOccurrences(of: "DOWN_HTML", with: htmlString)
    }

    public static func getPreviewStyle(theme: String? = nil, fullScreen: Bool = false, useFixedImageHeight: Bool = true) -> String {
        var css =
            useFixedImageHeight
                ? String("img { max-width: 100%; max-height: 90vh; }")
                : String()

        if let cssURL = UserDefaultsManagement.markdownPreviewCSS {
            if FileManager.default.fileExists(atPath: cssURL.path), let content = try? String(contentsOf: cssURL) {
                css = content
            }
        }

        let theme = theme ?? UserDefaultsManagement.codeTheme

        var codeStyle = String()
        if let hgPath = Bundle(for: Highlightr.self).path(forResource: theme + ".min", ofType: "css") {
            codeStyle = try! String.init(contentsOfFile: hgPath)
        }

        #if os(iOS)
            let codeFamilyName = UserDefaultsManagement.codeFont.familyName
            var familyName = UserDefaultsManagement.noteFont.familyName
        #else
            let codeFamilyName = UserDefaultsManagement.codeFont.familyName ?? ""
            var familyName = UserDefaultsManagement.noteFont.familyName ?? ""
        #endif

        if familyName.starts(with: ".") {
            familyName = "Helvetica Neue";
        }

        #if os(iOS)
            var width = 10
        #else
            var width = ViewController.shared()!.editArea.getWidth()
        #endif

        if fullScreen {
            width = 0
        }

        let tagAttributes = [NSAttributedString.Key.font: UserDefaultsManagement.codeFont]
        let oneCharSize = ("A" as NSString).size(withAttributes: tagAttributes as [NSAttributedString.Key : Any])
        let codeLineHeight = UserDefaultsManagement.editorLineSpacing / 2 + Float(oneCharSize.height)

        // Line height compute
        let lineHeight = Int(UserDefaultsManagement.editorLineSpacing) + Int(UserDefaultsManagement.noteFont.lineHeight)

        return "body {font: \(UserDefaultsManagement.fontSize)px '\(familyName)', '-apple-system'; margin: 0 \(width + 5)px; } code, pre {font: \(UserDefaultsManagement.codeFontSize)px '\(codeFamilyName)', Courier, monospace, 'Liberation Mono', Menlo; line-height: \(codeLineHeight)px; } img {display: block; margin: 0 auto;} p, li, blockquote, dl, ol, ul { line-height: \(lineHeight)px; } \(codeStyle) \(css)"
    }

    public func clean() {
        try? loadHTMLView("", css: "")
    }
}

class HandlerSelection: NSObject, WKScriptMessageHandler {
    public static var selectionString: String?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        let message = (message.body as! String).trimmingCharacters(in: .whitespacesAndNewlines)

        HandlerSelection.selectionString = message
    }
}

class HandlerCheckbox: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {

        guard let position = message.body as? String else { return }
        guard let note = EditTextView.note else { return }

        let content = note.content.unLoadCheckboxes().unLoadImages()
        let string = content.string
        let range = NSRange(0..<string.count)

        var i = 0
        NotesTextProcessor.allTodoInlineRegex.matches(string, range: range) { (result) -> Void in
            guard let range = result?.range else { return }

            if i == Int(position) {
                let substring = content.mutableString.substring(with: range)

                if substring.contains("- [x] ") {
                    content.replaceCharacters(in: range, with: "- [ ] ")
                } else {
                    content.replaceCharacters(in: range, with: "- [x] ")
                }

                #if os(iOS)
                AudioServicesPlaySystemSound(1519)
                #endif

                note.save(content: content)
            }

            i = i + 1
        }
    }
}

class HandlerMouse: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {

        guard let action = message.body as? String else { return }

        #if os(OSX)
        if action == "enter" {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
        #endif
    }
}

class HandlerClipboard: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {

        guard let action = message.body as? String else { return }

        var cleanText = action.trim()
        if cleanText.last == "\n" {
            cleanText.removeLast()
        }

        #if os(OSX)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cleanText, forType: .string)
        #else
            UIPasteboard.general.setItems([
                [kUTTypePlainText as String: cleanText]
            ])
        #endif
    }
}
