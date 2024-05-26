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
    
    if UserDefaultsManagement.soulverPreview {
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

    var customization: EngineCustomization = .standard
    customization.featureFlags.variableDeclarations = true /// Add the variable declarations feature
    let calculator = Calculator(customization: customization) /// Use this customization with a new Calculator object

    let content = NSMutableAttributedString(string: markdown)
    var update = [String: String]()

    FSParser.soulverRegex.regularExpression.enumerateMatches(in: markdown, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(0..<markdown.count), using:
            {(result, flags, stop) -> Void in
        
        guard let replaceRange = result?.range(at: 0), let codeRange = result?.range(at: 2) else { return }

        let codeBlock = FSParser.getFencedCodeBlockRange(paragraphRange: codeRange, string: content)
        let spanBlock = FSParser.getSpanCodeBlockRange(content: content, range: codeRange)

        if codeBlock != nil || spanBlock != nil {
            return
        }

        guard let replace = markdown.substring(with: replaceRange),
              let code = markdown.substring(with: codeRange),
              !replace.hasPrefix("\\")
        else { return }

        let newReplace = generateAlphabeticalString(length: replace.count)
        let result = calculator.calculate(String(code)).stringValue

        if result.count != 0 {
            update[newReplace] = result
            content.replaceCharacters(in: replaceRange, with: newReplace)
        }
    })

    var html = content.string
    for (key, value) in update {
        html = html.replacingOccurrences(of: key, with: value)
    }

    return html
}

func generateAlphabeticalString(length: Int) -> String {
    let alphabet = "abcdefghijklmnopqrstuvwxyz"
    var result = "@"
    let length = length - 2

    for _ in 0..<length {
        let randomIndex = Int.random(in: 0..<alphabet.count)
        let randomChar = alphabet[alphabet.index(alphabet.startIndex, offsetBy: randomIndex)]
        result.append(randomChar)
    }

    result.append("@")

    return result
}
