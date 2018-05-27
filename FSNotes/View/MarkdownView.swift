//
//  DownView.swift
//  Down
//
//  Created by Rob Phillips on 6/1/16.
//  Copyright © 2016 Glazed Donut, LLC. All rights reserved.
//

import WebKit
import Highlightr

// MARK: - Public API

public typealias DownViewClosure = () -> ()

open class MarkdownView: WKWebView {
    
    /**
     Initializes a web view with the results of rendering a CommonMark Markdown string
     
     - parameter frame:               The frame size of the web view
     - parameter markdownString:      A string containing CommonMark Markdown
     - parameter openLinksInBrowser:  Whether or not to open links using an external browser
     - parameter templateBundle:      Optional custom template bundle. Leaving this as `nil` will use the bundle included with Down.
     - parameter didLoadSuccessfully: Optional callback for when the web content has loaded successfully
     
     - returns: An instance of Self
     */
    public init(imagesStorage: URL? = nil, frame: CGRect, markdownString: String, openLinksInBrowser: Bool = true, css: String, templateBundle: Bundle? = nil, didLoadSuccessfully: DownViewClosure? = nil) throws {
        self.didLoadSuccessfully = didLoadSuccessfully
        
        if let templateBundle = templateBundle {
            self.bundle = templateBundle
        } else {
            let classBundle = Bundle(for: MarkdownView.self)
            let url = classBundle.url(forResource: "DownView", withExtension: "bundle")!
            self.bundle = Bundle(url: url)!
        }
        
        let userContentController = WKUserContentController()
        
        #if os(OSX)
            userContentController.add(HandlerCopyCode(), name: "notification")
            userContentController.add(HandlerMouseOver(), name: "mouseover")
            userContentController.add(HandlerMouseOut(), name: "mouseout")
        #endif
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        super.init(frame: frame, configuration: configuration)
        
        if openLinksInBrowser || didLoadSuccessfully != nil { navigationDelegate = self }
        try loadHTMLView(markdownString, css: getPreviewStyle(), imagesStorage: imagesStorage)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - API
    
    /**
     Renders the given CommonMark Markdown string into HTML and updates the DownView while keeping the style intact
     
     - parameter markdownString:      A string containing CommonMark Markdown
     - parameter didLoadSuccessfully: Optional callback for when the web content has loaded successfully
     
     - throws: `DownErrors` depending on the scenario
     */
    public func update(markdownString: String, didLoadSuccessfully: DownViewClosure? = nil) throws {
        // Note: As the init method takes this callback already, we only overwrite it here if
        // a non-nil value is passed in
        if let didLoadSuccessfully = didLoadSuccessfully {
            self.didLoadSuccessfully = didLoadSuccessfully
        }
        
        try loadHTMLView(markdownString, css: "")
    }
    
    private func getPreviewStyle() -> String {
        var codeStyle = ""
        if let hgPath = Bundle(for: Highlightr.self).path(forResource: UserDefaultsManagement.codeTheme + ".min", ofType: "css") {
            codeStyle = try! String.init(contentsOfFile: hgPath)
        }
        
        let familyName = UserDefaultsManagement.noteFont.familyName
        
        #if os(iOS)
            if #available(iOS 11.0, *) {
                var font = UserDefaultsManagement.noteFont
                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                font = fontMetrics.scaledFont(for: font!)
                if let fontSize = font?.pointSize {
                    let fs = Int(fontSize)
                    return "body {font: \(fs)pt \(familyName); } code, pre {font: \(fs)pt Courier New; font-weight: bold; } img {display: block; margin: 0 auto;} \(codeStyle)"
                }
            }
        #endif
        
        return "body {font: \(UserDefaultsManagement.fontSize)px \(familyName); } code, pre {font: \(UserDefaultsManagement.fontSize)px Source Code Pro;} img {display: block; margin: 0 auto;} \(codeStyle)"
    }
    
    // MARK: - Private Properties
    
    let bundle: Bundle
    
    fileprivate lazy var baseURL: URL = {
        return self.bundle.url(forResource: "index", withExtension: "html")!
    }()
    
    fileprivate var didLoadSuccessfully: DownViewClosure?
}

// MARK: - Private API

private extension MarkdownView {
    
    func loadHTMLView(_ markdownString: String, css: String, imagesStorage: URL? = nil) throws {
        var htmlString = try markdownString.toHTML()
        
        if let imagesStorage = imagesStorage {
            htmlString = loadImages(imagesStorage: imagesStorage, html: htmlString)
        }
        
        let pageHTMLString = try htmlFromTemplate(htmlString, css: css)
        
        loadHTMLString(pageHTMLString, baseURL: baseURL)
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
                let localPath = image.replacingOccurrences(of: "<img src=\"", with: "").dropLast()
                
                if localPath.starts(with: "/") {
                    let fullImageURL = imagesStorage
                    let imageURL = fullImageURL.appendingPathComponent(String(localPath))
                    let imageData = try Data(contentsOf: imageURL)
                    let base64prefix = "<img class=\"center\" src=\"data:image;base64," + imageData.base64EncodedString() + "\""
                    
                    htmlString = htmlString.replacingOccurrences(of: image, with: base64prefix)
                }
            }
        } catch let error {
            print("Images regex: \(error.localizedDescription)")
        }
        
        return htmlString
    }
    
    func htmlFromTemplate(_ htmlString: String, css: String) throws -> String {
        var template = try NSString(contentsOf: baseURL, encoding: String.Encoding.utf8.rawValue)
        template = template.replacingOccurrences(of: "DOWN_CSS", with: css) as NSString
        return template.replacingOccurrences(of: "DOWN_HTML", with: htmlString)
    }
    
}

// MARK: - WKNavigationDelegate

extension MarkdownView: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return }
        
        switch navigationAction.navigationType {
        case .linkActivated:
            decisionHandler(.cancel)
            #if os(iOS)
                UIApplication.shared.openURL(url)
            #elseif os(OSX)
                NSWorkspace.shared.open(url)
            #endif
        default:
            decisionHandler(.allow)
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didLoadSuccessfully?()
    }
    
}

#if os(OSX)
class HandlerCopyCode: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        let message = (message.body as! String).trimmingCharacters(in: .whitespacesAndNewlines)
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(message, forType: NSPasteboard.PasteboardType.string)
    }
}

class HandlerMouseOver: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        NSCursor.pointingHand.set()
    }
}

class HandlerMouseOut: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        NSCursor.arrow.set()
    }
}
#endif

