//
//  Markdown.swift
//  FSNotes
//
//  Created by Wonsup Yoon on 05/10/2019.
//  Copyright © 2019 Oleksandr Glushchenko. All rights reserved.
//

import libcmark_gfm

/// Replaces Markdown horizontal-rule lines without touching fenced code blocks.
func replaceHorizontalRulesOutsideCodeBlocks(in markdown: String) -> String {
    let lines = markdown.components(separatedBy: "\n")
    var result: [String] = []
    var fenceLength: Int?

    for (index, line) in lines.enumerated() {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let content = String(line.dropFirst(min(leadingSpaces, 3)))
        let characters = Array(content)

        if let currentFenceLength = fenceLength {
            if characters.first == "`",
               characters.prefix(while: { $0 == "`" }).count >= currentFenceLength {
                fenceLength = nil
            }
        } else if characters.first == "`" {
            let length = characters.prefix(while: { $0 == "`" }).count
            if length >= 3 {
                fenceLength = length
            }
        }

        // Keep the existing behavior for a standalone `---` line, including
        // its requirement for a following newline, but only outside code.
        if fenceLength == nil && line == "---" && index > 0 && index < lines.count - 1 {
            result.append("<hr>")
        } else {
            result.append(line)
        }
    }

    return result.joined(separator: "\n")
}

func renderMarkdownHTML(markdown: String, sourcePositions: Bool = false) -> String? {
    let markdown = markdown.replacingOccurrences(of: "{{TOC}}", with: "<div id=\"toc\"></div>")
        
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
    let options = CMARK_OPT_HARDBREAKS | CMARK_OPT_UNSAFE | (sourcePositions ? CMARK_OPT_SOURCEPOS : 0)
    return String(cString: cmark_render_html(node, options, nil))
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
