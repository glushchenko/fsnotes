//
//  Markdown.swift
//  FSNotes
//
//  Created by Wonsup Yoon on 05/10/2019.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import libcmark_gfm
import SoulverCore

func renderMarkdownHTML(markdown: String) -> String? {
    var markdown = markdown.replacingOccurrences(of: "{{TOC}}", with: "<div id=\"toc\"></div>")
    
    if #available(OSX 10.15, *), UserDefaultsManagement.soulverPreview {
        markdown = renderSoulverCodeBlocks(markdown: markdown)
    }
    
    cmark_gfm_core_extensions_ensure_registered()
    
    guard let parser = cmark_parser_new(CMARK_OPT_FOOTNOTES) else { return nil }
    defer { cmark_parser_free(parser) }

    if let ext = cmark_find_syntax_extension("table") {
        cmark_parser_attach_syntax_extension(parser, ext)
    }

    if let ext = cmark_find_syntax_extension("autolink") {
        cmark_parser_attach_syntax_extension(parser, ext)
    }

    if let ext = cmark_find_syntax_extension("strikethrough") {
        cmark_parser_attach_syntax_extension(parser, ext)
    }
    
    if let ext = cmark_find_syntax_extension("tasklist") {
        cmark_parser_attach_syntax_extension(parser, ext)
    }

    cmark_parser_feed(parser, markdown, markdown.utf8.count)
    guard let node = cmark_parser_finish(parser) else { return nil }
    return String(cString: cmark_render_html(node, CMARK_OPT_HARDBREAKS | CMARK_OPT_UNSAFE, nil))
}

func renderSoulverCodeBlocks(markdown: String) -> String {
    var html = markdown
    let calculator = Calculator(customization: .standard)
    
    FSParser.soulverRegex.regularExpression.enumerateMatches(in: markdown, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(0..<markdown.count), using:
            {(result, flags, stop) -> Void in
        
        guard let replaceRange = result?.range(at: 0), let codeRange = result?.range(at: 2) else { return }
        
        guard let replace = markdown.substring(with: replaceRange),
              let code = markdown.substring(with: codeRange),
            !replace.hasPrefix("\\")
        else { return }
        
        let result = calculator.calculate(String(code)).stringValue
        
        if result.count != 0 {
            html = html.replacingOccurrences(of: replace, with: result)
        }
    })
    
    return html
}
