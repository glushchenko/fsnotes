//
//  MPreviewView.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 8/17/19.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import WebKit
import Highlightr
import SSZipArchive

#if os(iOS)
import NightNight
import MobileCoreServices
import AudioToolbox
#else
import Carbon.HIToolbox
#endif

public typealias MPreviewViewClosure = () -> ()

class MPreviewView: WKWebView, WKUIDelegate, WKNavigationDelegate {

    private var editorVC: EditorViewController?
    private weak var note: Note?
    private var closure: MPreviewViewClosure?
    public static var template: String?
    
    init(frame: CGRect, note: Note, closure: MPreviewViewClosure?, force: Bool = false) {
        self.closure = closure
        let userContentController = WKUserContentController()
        userContentController.add(HandlerSelection(), name: "newSelectionDetected")
        
        let handlerCheckbox = HandlerCheckbox(note: note)
        userContentController.add(handlerCheckbox, name: "checkbox")
        userContentController.add(HandlerMouse(), name: "mouse")
        userContentController.add(HandlerClipboard(), name: "clipboard")
        userContentController.add(HandlerOpen(), name: "open")

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
    
    public func setEditorVC(evc: EditorViewController? = nil) {
        self.editorVC = evc
    }

#if os(OSX)
    override func mouseDown(with event: NSEvent) {
        guard let evc = editorVC else {
            super.mouseDown(with: event)
            return
        }
        
        if let note = evc.vcEditor?.note {
            if note.container == .encryptedTextPack && !note.isUnlocked() {
                evc.unLock(notes: [note])
            } else if note.content.length == 0 {
                evc.vcEditor?.disablePreviewEditorAndNote()
                
                evc.refillEditArea()
                evc.focusEditArea()
            }
        }
        
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Return {
            DispatchQueue.main.async {
                if let evc = self.editorVC {
                    evc.vcEditor?.disablePreviewEditorAndNote()
                    
                    evc.refillEditArea()
                    evc.focusEditArea()
                }
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
        self.note = note
        
        let markdownString = note.getPrettifiedContent()

        if let urls = note.imageUrl, urls.count > 0 {
            cleanCache()
            
            let dst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wkPreview")
            
            if let i = MPreviewView.buildPage(for: note, at: dst) {
                if getppid() != 1 {
                    print("Web view loaded from: \(i)")
                }
                
                let accessURL = i.deletingLastPathComponent()
                loadFileURL(i, allowingReadAccessTo: accessURL)
            }
        } else {
            let htmlString = renderMarkdownHTML(markdown: markdownString)!
            guard let pageHTMLString = try? MPreviewView.htmlFromTemplate(htmlString) else { return }

            var baseURL: URL?
            if let path = Bundle.main.path(forResource: "MPreview", ofType: ".bundle") {
                let url = NSURL.fileURL(withPath: path)
                if let bundle = Bundle(url: url) {
                    baseURL = bundle.url(forResource: "index", withExtension: "html")
                }
            }

            loadHTMLString(pageHTMLString, baseURL: baseURL)
        }
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

    public static func getMathJaxJS() -> String {
        if !UserDefaultsManagement.mathJaxPreview {
            return String()
        }

        let inline = "['$', '$'], ['\\(', '\\)'], ['$$', '$$'], ['\\((', '\\))']"

        return """
            <script>
            MathJax = {
              tex: {
                inlineMath: [\(inline)]
              }
            };
            </script>
            <script id="MathJax-script" async src="{WEB_PATH}js/tex-mml-chtml.js"></script>
        """
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
    
    public static func buildPage(for note: Note, at dst: URL, web: Bool = false, print: Bool = false) -> URL? {
        var markdownString = note.getPrettifiedContent()
        
        // Hack for WebView compatibility
        if print {
            markdownString = MPreviewView.assignBase64Images(note: note, html: markdownString)
        }
        
        var htmlString = renderMarkdownHTML(markdown: markdownString)!
        
        var imagesStorage = note.project.url
        if note.isTextBundle() {
            imagesStorage = note.getURL()
        }
        
        var webPath: String?
        var zipName: String?
        
        // For uploaded content
        if web {
            // Generate zip
            zipName = "\(note.getLatinName()).zip"
            
            let zipURL = dst.appendingPathComponent(note.getLatinName()).appendingPathExtension("zip")
            try? FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true, attributes: nil)
            
            if note.container == .none {
                SSZipArchive.createZipFile(atPath: zipURL.path, withFilesAtPaths: [note.url.path])
            } else {
                SSZipArchive.createZipFile(atPath: zipURL.path, withContentsOfDirectory: note.url.path, keepParentDirectory: true)
            }
            
            if UserDefaultsManagement.customWebServer {
                webPath = UserDefaultsManagement.sftpWeb
            } else {
                webPath = UserDefaultsManagement.webPath
            }
        }
        
        if let urls = note.imageUrl, urls.count > 0, !print {
            htmlString = MPreviewView.loadImages(imagesStorage: imagesStorage, html: htmlString, at: dst, web: web)
        }
        
        if let pageHTMLString = try? htmlFromTemplate(htmlString, webPath: webPath, print: print, archivePath: zipName, note: note) {
            let indexURL = createTemporaryBundle(pageHTMLString: pageHTMLString, at: dst)
            
            return indexURL
        }
        
        return nil
    }

    public static func createTemporaryBundle(pageHTMLString: String, at: URL) -> URL? {
        let path = Bundle.main.path(forResource: "MPreview", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)

        guard let bundleResourceURL = bundle?.resourceURL else { return nil }

        var customCSS: URL? = UserDefaultsManagement.markdownPreviewCSS
        
        #if os(iOS)
            customCSS = nil
        #endif

        let webkitPreview = at
        try? FileManager.default.createDirectory(at: webkitPreview, withIntermediateDirectories: true, attributes: nil)

        let indexURL = webkitPreview.appendingPathComponent("index.html")
        let mainCssUrl = webkitPreview.appendingPathComponent("main.css")

        // If updating markdown contents, no need to re-copy bundle.
        if !FileManager.default.fileExists(atPath: indexURL.path) || !FileManager.default.fileExists(atPath: mainCssUrl.path) {
            // Copy bundle resources to temporary location.
            do {
                let fileList = try FileManager.default.contentsOfDirectory(atPath: bundleResourceURL.path)

                for file in fileList {
                    print(file)
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
            let styleDst = webkitPreview.appendingPathComponent("main.css", isDirectory: false)

            do {
                _ = try FileManager.default.copyItem(at: customCSS, to: styleDst)
            } catch {
                print(error)
            }
        }

        // Write generated index.html to temporary location.
        try? pageHTMLString.write(to: indexURL, atomically: true, encoding: .utf8)

        
        let xxxUrl = URL(fileURLWithPath: "file:///private/var/mobile/Containers/Data/Application/61C1111B-8C3A-4EE7-AB0F-EFBBED81D1C4/tmp/wkPreview/")
        
        print(indexURL.deletingLastPathComponent().path)
        print(try? FileManager.default.contentsOfDirectory(atPath: indexURL.deletingLastPathComponent().path))
        
        return indexURL
    }

    public static func loadImages(imagesStorage: URL, html: String, at: URL, web: Bool = false) -> String {
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

                let webkitPreview = at

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
                
                // Uploaded over API or SSH
                if web {
                    localPath = "i/\(imageURL.lastPathComponent)"
                }

                let imPath = "<img data-orientation=\"\(orientation)\" class=\"fsnotes-preview\" src=\"" + localPath + "\""

                htmlString = htmlString.replacingOccurrences(of: image, with: imPath)
            }
        } catch let error {
            print("Images regex: \(error.localizedDescription)")
        }

        return htmlString
    }

    public static func htmlFromTemplate(_ htmlString: String, webPath: String? = nil, print: Bool = false, archivePath: String? = nil, note: Note? = nil) throws -> String {
        let webPath = webPath ?? ""

        var htmlString = htmlString
        let path = Bundle.main.path(forResource: "MPreview", ofType: ".bundle")
        let url = NSURL.fileURL(withPath: path!)
        let bundle = Bundle(url: url)
        let baseURL = bundle!.url(forResource: "index", withExtension: "html")!

        var template = try String(contentsOf: baseURL, encoding: .utf8)
        var platform = String()
        var appearance = String()
        
        let isWeb = webPath.count > 0
        let preview = String(webPath.count == 0)

#if os(iOS)
        platform = "ios"
        if NightNight.theme == .night && archivePath == nil {
            appearance = "darkmode"
        }
#else
        platform = "macos"
        if UserDataService.instance.isDark && archivePath == nil {
            appearance = "darkmode"
        }
#endif
        
        if webPath.count > 0 {
             htmlString = """
                <style>
                    
                    article {
                        max-width: 1280px;
                        margin: 0 auto;
                        margin-bottom: 70px;
                    }
            
                    footer {
                        max-width: 1280px;
                        margin: 0 auto;
                        background: white;
                        position: fixed;
                        left: 0;
                        right: 0;
                        bottom: 0;
                        height: 60px;
                        width: 100%;
                        padding: 10px 20px 20px 20px;
                        border-top: 1px solid gray;
                    }
            
                    img.logo {
                        display: inline-block;
                        height: 32px;
                        width: 32px;
                    }
            
                    .footer__span {
                        display: inline-block;
                        line-height: 32px;
                        margin: 3px 0 0 0;
                    }
                        .footer__span__archive {
                            float: right;
                        }
            
                    .share-button {
                      border: 1px solid #eee;
                      border-radius: 4px;
                      color: #999;
                      cursor: pointer;
                      display: inline-block;
                      font-weight: 600;
                      line-height: 1.7;
                      padding: 6px 17px;
                      text-decoration: none;
                    }
                        .share-button .label i {
                          margin-right: 0.4em;
                        }
                        .share-button .sites {
                          display: none;
                          line-height: 1;
                          vertical-align: middle;
                        }
                        .share-button .sites a {
                          color: #777;
                          font-size: 1.2em;
                          margin-left: 0.3em;
                        }
                        .share-button .sites a:hover.facebook {
                          color: #385797;
                        }
                        .share-button .sites a:hover.twitter {
                          color: #03abea;
                        }
            
                        .share-button .sites a:hover.linkedin {
                          color: #0078a8;
                        }
                        .share-button .sites a:hover.pinterest {
                          color: #c91515;
                        }
                        .share-button:hover {
                          border-color: #ddd;
                          box-shadow: 0.1em 0.1em 0.3em rgba(0, 0, 0, 0.05);
                          color: #777;
                        }
                        .share-button:hover .sites {
                          display: inline-block;
                        }
            
                        @media screen and (max-width: 400px) {
                            .share-button .label {
                                display: none;
                            }
                        }
            
                    .macos ul.cb {
                        margin-left: 0;
                    }
                </style>
                <article>\(htmlString)</article>
                
                <footer>
                    <span class="footer__span">Powered by <a href="https://fsnot.es" target="_blank">FSNotes App</a> <img class="logo" src="https://fsnot.es/img/icon.webp" style="margin: 0 0 -10px 0;"></span>
                    <a class="share-button" href="\(archivePath!)" style="float: right; text-decoration: none;">
                        <span class="label" style="vertical-align: middle;">Download</span>
                        <span style="display: inline-block; height: 17px; width: 17px; vertical-align: middle;">
                            <svg viewBox="0 0 24 24"><path d="M0 0h24v24H0z" fill="none"/><path d="M4 19h16v-7h2v8a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1v-8h2v7zM14 9h5l-7 7-7-7h5V3h4v6z"/></svg>
                        </span>
                    </a>
                </footer>
            """
        }
        
        var title = String()
        if let unwrapped = note?.getTitle() {
            title = unwrapped
        }
        
        let inlineCss = MPreviewView.getPreviewStyle(print: print, forceLightTheme: isWeb)
        
        template = template
            .replacingOccurrences(of: "{TITLE}", with: title)
            .replacingOccurrences(of: "{INLINE_CSS}", with: inlineCss)
            .replacingOccurrences(of: "{MATH_JAX_JS}", with: MPreviewView.getMathJaxJS())
            .replacingOccurrences(of: "{FSNOTES_APPEARANCE}", with: appearance)
            .replacingOccurrences(of: "{FSNOTES_PLATFORM}", with: platform)
            .replacingOccurrences(of: "{FSNOTES_PREVIEW}", with: preview)
            .replacingOccurrences(of: "{NOTE_BODY}", with: htmlString)
            .replacingOccurrences(of: "{WEB_PATH}", with: webPath)
        
        return template
    }

    public static func getPreviewStyle(print: Bool = false, forceLightTheme: Bool = false) -> String {
        var theme: String? = nil
        var fullScreen = false
        var useFixedImageHeight = true
        var css = "<style>"
        
        if print {
            theme = "github"
            fullScreen = true
            useFixedImageHeight = false
        }
        
        if let cssURL = UserDefaultsManagement.markdownPreviewCSS {
            if FileManager.default.fileExists(atPath: cssURL.path), let content = try? String(contentsOf: cssURL) {
                css += content
            }
        }
        
        css +=
            useFixedImageHeight
                ? String("img { max-width: 100%; max-height: 90vh; }")
                : String()

        theme = theme ?? UserDefaultsManagement.codeTheme
        
        if forceLightTheme {
            theme = UserDefaultsManagement.lightCodeTheme
        }

        var codeStyle = String()
        if let hgPath = Bundle(for: Highlightr.self).path(forResource: theme! + ".min", ofType: "css") {
            codeStyle = try! String.init(contentsOfFile: hgPath)
        }

        #if os(iOS)
            let codeFamilyName = UserDefaultsManagement.codeFont.familyName
            var familyName = UserDefaultsManagement.noteFont.familyName
            let tagColor = "#6692cb"
        #else
            let codeFamilyName = UserDefaultsManagement.codeFont.familyName ?? ""
            var familyName = UserDefaultsManagement.noteFont.familyName ?? ""
            let tagColor = NSColor.tagColor.hexString
        #endif

        if familyName.starts(with: ".") {
            familyName = "Helvetica Neue";
        }

        #if os(iOS)
            var width = 10
        #else
            var width = ViewController.shared()!.editor.getWidth()
        #endif

        if fullScreen {
            width = 0
        }

        let tagAttributes = [NSAttributedString.Key.font: UserDefaultsManagement.codeFont]
        let oneCharSize = ("A" as NSString).size(withAttributes: tagAttributes as [NSAttributedString.Key : Any])
        let codeLineHeight = UserDefaultsManagement.editorLineSpacing / 2 + Float(oneCharSize.height)

        // Line height compute
        let lineHeight = Int(UserDefaultsManagement.editorLineSpacing) + Int(UserDefaultsManagement.noteFont.lineHeight)

        var result = """
            @font-face {
                font-family: 'Source Code Pro';
                src: url('{WEB_PATH}fonts/SourceCodePro-Regular.ttf')
                format('truetype');
            }

            @font-face {
                font-family: 'Source Code Pro';
                src: url('{WEB_PATH}fonts/SourceCodePro-Bold.ttf');
                font-weight: bold;
            }
        
            body {font: \(UserDefaultsManagement.fontSize)px '\(familyName)', '-apple-system'; margin: 0 \(width + 5)px; }
            code, pre {font: \(UserDefaultsManagement.codeFontSize)px '\(codeFamilyName)', Courier, monospace, 'Liberation Mono', Menlo; line-height: \(codeLineHeight + 3)px; }
            img {display: block; margin: 0 auto;}
            a[href^=\"fsnotes://open/?tag=\"] { background: \(tagColor); }
            p, li, blockquote, dl, ol, ul { line-height: \(lineHeight)px; } \(codeStyle) \(css)
        
            #MathJax_Message+* {
                margin-top: 0 !important;
            }
        """
                
        if print {
            result += """
                body { -webkit-text-size-adjust: none; font-size: 1.0em;}
                pre, code { border: 1px solid #c0c4ce; border-radius: 3px; }
                pre, pre code { word-wrap: break-word; }
            """
        }
        
        css += result
        css += "</style>"
        
        return css
    }
    
    public static func assignBase64Images(note: Note, html: String) -> String {
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

    public func clean() {
        loadHTMLString("", baseURL: nil)
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
    private var note: Note?
    
    init(note: Note) {
        self.note = note
    }
    
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {

        guard let position = message.body as? String else { return }
        guard let note = self.note else { return }

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

class HandlerOpen: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {

        guard let action = message.body as? String else { return }
        let cleanText = action.trim()
        
        if cleanText.contains("wkPreview/index.html") {
            return
        }
        
        #if os(OSX)
            if let url = URL(string: cleanText) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        #endif
    }
}
