import Foundation
import libxml2

struct HTMLClip {
    let title: String
    let text: String

    init(plainText: String, title: String? = nil) throws {
        guard let firstLine = plainText.split(whereSeparator: \.isNewline)
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .first(where: { !$0.isEmpty }) else { throw CocoaError(.fileReadCorruptFile) }
        self.title = title ?? firstLine
        self.text = plainText
    }

    init(data: Data, title: String? = nil, source: URL? = nil, baseURL: URL? = nil, encoding: String? = nil, asMarkdown: Bool = true) throws {
        let document = try Self.parse(data, encoding: encoding)
        defer { xmlFreeDoc(document) }
        let root = xmlDocGetRootElement(document).map(HTMLNode.init)
        let head = root?.children.first { $0.name == "head" }
        // libxml's HTML4 parser can leave an HTML5 article in head when body tags are omitted.
        let body = root?.children.first { $0.name == "body" }
            ?? head?.firstDescendant(named: "article") ?? root
        let pageTitle = (title ?? head?.children.first { $0.name == "title" }?.text ?? source?.host)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.title = pageTitle.isEmpty ? NSLocalizedString("Shared Page", comment: "") : pageTitle

        let base = head?.children.first { $0.name == "base" }?.attribute("href")
        let baseURL = base.flatMap { URL(string: $0, relativeTo: baseURL ?? source)?.absoluteURL }
            ?? baseURL ?? source
        let main = body?.firstDescendant(named: "main")
        let content = (main ?? body)?.firstDescendant(named: "article")
            ?? main ?? body?.proseSummary().container?.node ?? body
        let rendered = content.map { Self.render($0, baseURL: baseURL, asMarkdown: asMarkdown) } ?? ""
        let text = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CocoaError(.fileReadCorruptFile) }

        self.text = text + "\n"
    }

    private static func parse(_ data: Data, encoding: String?) throws -> xmlDocPtr {
        guard let length = Int32(exactly: data.count) else { throw CocoaError(.fileReadTooLarge) }
        let options = HTML_PARSE_NODEFDTD.rawValue | HTML_PARSE_NONET.rawValue
            | HTML_PARSE_NOERROR.rawValue | HTML_PARSE_NOWARNING.rawValue
        let encoding = encoding ?? (String(data: data, encoding: .utf8) != nil ? "UTF-8" : nil)
        let html = data.withUnsafeBytes { bytes in
            htmlReadMemory(bytes.bindMemory(to: CChar.self).baseAddress, length, nil, encoding, Int32(options))
        }
        guard let html else { throw CocoaError(.fileReadCorruptFile) }
        return html
    }

    private static func render(_ node: HTMLNode, baseURL: URL?, asMarkdown: Bool) -> String {
        if node.type == XML_TEXT_NODE {
            let text = node.text.replacingOccurrences(of: "[\\t\\r\\n ]+", with: " ", options: .regularExpression)
            return asMarkdown ? escape(text) : text
        }

        guard node.type == XML_ELEMENT_NODE, !node.isNoise else { return "" }

        let name = node.name
        if name == "p", node.isPagination { return "" }
        switch name {
        case "br":
            return asMarkdown ? "  \n" : "\n"
        case "hr":
            return asMarkdown ? "\n\n---\n\n" : "\n\n"
        case "pre", "code":
            let code = node.text
            guard asMarkdown else { return name == "pre" ? "\n\n\(code)\n\n" : code }
            let longestRun = code.split(whereSeparator: { $0 != "`" }).map(\.count).max() ?? 0
            let fence = String(repeating: "`", count: max(name == "pre" ? 3 : 1, longestRun + 1))
            if name == "pre" {
                let closingBreak = code.isEmpty || code.last?.isNewline == true ? "" : "\n"
                return "\n\n\(fence)\(node.codeLanguage ?? Self.detectLanguage(code) ?? "")\n\(code)\(closingBreak)\(fence)\n\n"
            }
            let padding = code.first == "`" || code.last == "`" ? " " : ""
            return "\(fence)\(padding)\(code)\(padding)\(fence)"
        default:
            break
        }

        let children = node.children
        var rendered = ""
        for child in children {
            let fragment = render(child, baseURL: baseURL, asMarkdown: asMarkdown)
            if fragment.hasPrefix("\n\n") {
                while rendered.last?.isWhitespace == true { rendered.removeLast() }
            }
            if asMarkdown, rendered.last == "!", fragment.hasPrefix("[") {
                // A literal exclamation mark immediately before a link would turn it into an image.
                rendered.insert("\\", at: rendered.index(before: rendered.endIndex))
            }
            if rendered.hasSuffix("\n\n") {
                rendered += fragment.drop(while: { $0 == " " })
            } else {
                rendered += fragment
            }
        }
        let text = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            guard !text.isEmpty else { return "" }
            let level = Int(name.dropFirst()) ?? 1
            let prefix = asMarkdown ? String(repeating: "#", count: level) + " " : ""
            return "\n\n\(prefix)\(text)\n\n"
        case "p", "div", "section", "article", "main", "header", "figure", "figcaption":
            return "\n\n\(text)\n\n"
        case "b", "strong", "i", "em", "s", "del":
            guard asMarkdown, !text.isEmpty else { return rendered }
            let marker = ["b", "strong"].contains(name) ? "**" : ["s", "del"].contains(name) ? "~~" : "*"
            let leadingSpace = rendered.first?.isWhitespace == true ? " " : ""
            let trailingSpace = rendered.last?.isWhitespace == true ? " " : ""
            return leadingSpace + marker + text + marker + trailingSpace
        case "blockquote":
            return "\n\n" + (asMarkdown ? indent(text, with: "> ") : text) + "\n\n"
        case "ol", "ul":
            let requestedStart = Int(node.attribute("start") ?? "") ?? 1
            let start = (1...999_999_999).contains(requestedStart) ? requestedStart : 1
            let lines = children.filter { $0.name == "li" }.enumerated().map { index, item in
                let number = min(start + index, 999_999_999)
                let marker = name == "ul" ? "- " : "\(number). "
                let itemText = render(item, baseURL: baseURL, asMarkdown: asMarkdown).trimmingCharacters(in: .whitespacesAndNewlines)
                return marker + indent(itemText, with: String(repeating: " ", count: marker.count), skipFirst: true)
            }
            return "\n\n" + lines.joined(separator: "\n") + "\n\n"
        case "a":
            guard asMarkdown, let link = destination(node.attribute("href"), baseURL: baseURL),
                  !text.isEmpty else { return rendered }
            if text.contains(where: \.isNewline) {
                // Markdown link labels cannot span paragraphs. A block link is one line.
                let label = render(node, baseURL: baseURL, asMarkdown: false)
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                return "\n\n[\(escape(label))](\(link))\n\n"
            }
            let leadingSpace = rendered.first?.isWhitespace == true ? " " : ""
            let trailingSpace = rendered.last?.isWhitespace == true ? " " : ""
            return "\(leadingSpace)[\(text)](\(link))\(trailingSpace)"
        case "img":
            guard let src = node.attribute("src"), !src.isEmpty,
                  let url = URL(string: src, relativeTo: baseURL)?.absoluteURL,
                  !["svg", "svgz"].contains(url.pathExtension.lowercased()),
                  !node.isDecorativeImage,
                  let image = destination(src, baseURL: baseURL) else { return "" }
            let alt = node.attribute("alt") ?? ""
            return asMarkdown ? "![\(escape(alt))](\(image))" : alt
        case "tr":
            let cells = children.filter { $0.name == "th" || $0.name == "td" }
            return "\n\n" + cells.map { render($0, baseURL: baseURL, asMarkdown: asMarkdown) }.joined(separator: " | ") + "\n\n"
        default:
            return rendered
        }
    }

    private static let languagePatterns: [(String, NSRegularExpression)] = {
        let patterns: [(String, String)] = [
            ("bash", #"\A#![^\n]*\b(?:ba|z|da|k)?sh\b|(?m)^\s*[$%] (?:sudo |[a-z][\w-]*(?: |$))|^\s*(?:export [A-Za-z_]|if \[|fi$|echo )"#),
            ("python", #"\A#![^\n]*\bpython[\d.]*\b|(?m)^\s*(?:async )?def \w+\([^\n]*\):|^\s*(?:from [\w.]+ import |if __name__ ==)"#),
            ("php", #"<\?php\b"#),
            ("ruby", #"\A#![^\n]*\bruby\b|(?m)^\s*(?:require ['"]|def \w+[!?]?(?:\([^\n]*\))?\s*$)"#),
            ("perl", #"\A#![^\n]*\bperl\b|(?m)^\s*use (?:strict|warnings)\b"#),
            ("powershell", #"(?im)^\s*(?:Get|Set|New|Remove|Invoke|Write|Import)-[A-Za-z]+\b|\$env:[A-Za-z_]"#),
            ("typescript", #"(?m)\b(?:interface \w+\s*\{|type \w+\s*=)|\b(?:const|let) \w+\s*:\s*(?:string|number|boolean)\b"#),
            ("go", #"(?m)^package \w+\b|\bfunc \([^\n]+\) \w+\s*\("#),
            ("swift", #"(?m)^\s*import (?:Foundation|SwiftUI|UIKit|AppKit)\b|\bfunc \w+\s*\(|\b(?:guard|if) let \w+\s*="#),
            ("rust", #"\bfn \w+\s*\(|\b(?:impl|trait) \w+|\buse (?:std|crate)::"#),
            ("csharp", #"\busing (?:System|Microsoft)[.;]|\bConsole\.Write(?:Line)?\s*\(|\bnamespace [\w.]+\s*[;{]"#),
            ("java", #"\bimport java\.|\bSystem\.out\.print|\bpublic static void main\s*\("#),
            ("cpp", #"#\s*include\s*<(?:iostream|string|vector|map|memory|algorithm)>|\bstd::"#),
            ("c", #"#\s*include\s*[<"][^>"]+\.h[>"]|\b(?:int|void) main\s*\("#),
            ("html", #"(?i)<!doctype html|<(?:html|div|span|section|meta|script)\b[^>]*>"#),
            ("xml", #"<\?xml\b|(?s)^\s*<([A-Za-z_][\w:.-]*)\b[^>]*>.*</\1>\s*$"#),
            ("css", #"(?s)(?:[.#][\w-]+|:root|@media[^{}]+)\s*\{[^{}]*[\w-]+\s*:[^{}]+[;}]"#),
            ("sql", #"(?i)\bSELECT\b.+\bFROM\b|\bCREATE TABLE\b|\bINSERT INTO\b|\bALTER TABLE\b"#),
            ("javascript", #"\A#![^\n]*\bnode\b|\b(?:const|let|var) \w+\s*=|\b(?:async )?function\s*[\w$]*\s*\(|\bconsole\.log\s*\("#),
            ("yaml", #"(?m)^(?:[A-Za-z_][\w.-]*: +[^\n]+\n){2}"#),
            ("toml", #"(?m)^\[[\w.-]+\]\s*\n(?:[\w.-]+ *=)"#)
        ]
        return patterns.map { ($0.0, try! NSRegularExpression(pattern: $0.1)) }
    }()

    private static func detectLanguage(_ code: String) -> String? {
        // Limit scanning for large pasted examples while keeping explicit website labels authoritative.
        let sample = String(code.prefix(16_384))
        if let data = sample.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           json is [String: Any] || json is [Any] {
            return "json"
        }
        let range = NSRange(sample.startIndex..., in: sample)
        return languagePatterns.first { $0.1.firstMatch(in: sample, range: range) != nil }?.0
    }

    private static func indent(_ text: String, with prefix: String, skipFirst: Bool = false) -> String {
        text.components(separatedBy: "\n").enumerated().map { index, line in
            index == 0 && skipFirst ? line : prefix + line
        }.joined(separator: "\n")
    }

    private static func escape(_ text: String) -> String {
        var result = ""
        var atLineStart = true
        for index in text.indices {
            let character = text[index]
            let nextIndex = text.index(after: index)
            let next = nextIndex < text.endIndex ? text[nextIndex] : nil
            let startsHeading = character == "#" && atLineStart
                && (next == nil || next == "#" || next?.isWhitespace == true)
            let needsEscape = "\\`*_[]<|~".contains(character)
                || (character == ">" && atLineStart) || startsHeading
            if needsEscape { result.append("\\") }
            result.append(character)
            if character.isNewline {
                atLineStart = true
            } else if !character.isWhitespace {
                atLineStart = false
            }
        }
        return result
    }

    private static func destination(_ value: String?, baseURL: URL?) -> String? {
        guard let value, let url = URL(string: value, relativeTo: baseURL)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) else { return nil }
        return url.absoluteString
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
            .replacingOccurrences(of: "<", with: "%3C")
            .replacingOccurrences(of: ">", with: "%3E")
    }
}

private struct HTMLNode {
    let pointer: xmlNodePtr

    init(_ pointer: xmlNodePtr) {
        self.pointer = pointer
    }

    var type: xmlElementType { pointer.pointee.type }
    var name: String { pointer.pointee.name.map { String(cString: $0) } ?? "" }

    var text: String {
        guard let value = xmlNodeGetContent(pointer) else { return "" }
        defer { xmlFree(value) }
        return String(cString: value)
    }

    var children: [HTMLNode] {
        var nodes: [HTMLNode] = []
        var child = pointer.pointee.children
        while let current = child {
            nodes.append(HTMLNode(current))
            child = current.pointee.next
        }
        return nodes
    }

    func attribute(_ name: String) -> String? {
        let value = name.utf8CString.withUnsafeBufferPointer { bytes in
            bytes.baseAddress?.withMemoryRebound(to: xmlChar.self, capacity: bytes.count) {
                xmlGetProp(pointer, $0)
            }
        }
        guard let value else { return nil }
        defer { xmlFree(value) }
        return String(cString: value)
    }

    private static let noiseElements: Set<String> = [
        "script", "style", "head", "nav", "footer", "aside", "noscript", "template", "svg",
        "form", "button", "input", "select", "textarea", "dialog", "iframe", "canvas"
    ]
    private static let noiseRoles: Set<String> = [
        "navigation", "banner", "complementary", "contentinfo", "dialog", "menu", "toolbar", "search"
    ]

    private static let noiseClass = try! NSRegularExpression(
        pattern: #"(?:^|\s)(?:sr-only|visually-hidden|related[-_]?(?:posts|articles|content|stories)(?:[-_][^\s]*)?)(?=$|\s)"#,
        options: .caseInsensitive
    )

    var isNoise: Bool {
        if Self.noiseElements.contains(name) || Self.noiseRoles.contains(attribute("role") ?? "")
            || attribute("hidden") != nil || attribute("inert") != nil
            || attribute("data-export-skip") != nil {
            return true
        }
        guard let classes = attribute("class") else { return false }
        return Self.noiseClass.firstMatch(in: classes, range: NSRange(classes.startIndex..., in: classes)) != nil
    }

    var codeLanguage: String? {
        let code = firstDescendant(named: "code")
        let parent = pointer.pointee.parent.map(HTMLNode.init)
        let candidates = [code, self, parent].compactMap { $0 }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_+.#-"))
        for candidate in candidates {
            let classes = (candidate.attribute("class") ?? "").split(whereSeparator: \.isWhitespace)
            let classLanguage = classes.compactMap { name -> String? in
                for prefix in ["language-", "lang-", "highlight-source-"] where name.hasPrefix(prefix) {
                    return String(name.dropFirst(prefix.count))
                }
                return nil
            }.first
            for value in [classLanguage, candidate.attribute("data-language"), candidate.attribute("data-lang")] {
                guard let language = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !language.isEmpty, language.count <= 40,
                      language.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { continue }
                return language.lowercased()
            }
        }
        return nil
    }

    var isDecorativeImage: Bool {
        let width = attribute("width").flatMap(Double.init)
        let height = attribute("height").flatMap(Double.init)
        if let width, width <= 1 { return true }
        if let height, height <= 1 { return true }
        if let width, let height { return width <= 16 && height <= 16 }
        return false
    }

    var isPagination: Bool {
        guard firstDescendant(named: "a") != nil else { return false }
        return text.range(
            of: #"^[‹«←<\s]*(?:prev(?:ious)?(?:\s*[|/·]\s*next)?|next)[›»→>\s]*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    struct ProseSummary {
        var length = 0
        var paragraphs = 0
        var container: (node: HTMLNode, length: Int)?
    }

    // Older pages often put the article and navigation in adjacent table cells.
    // Choose a container only when it holds most of the page's prose.
    func proseSummary() -> ProseSummary {
        guard type == XML_ELEMENT_NODE, !isNoise else { return ProseSummary() }
        if ["p", "pre", "blockquote"].contains(name) {
            let length = proseLength
            return length >= 30 ? ProseSummary(length: length, paragraphs: 1) : ProseSummary()
        }

        var summary = ProseSummary()
        for child in children {
            let result = child.proseSummary()
            summary.length += result.length
            summary.paragraphs += result.paragraphs
            if let container = result.container, container.length > (summary.container?.length ?? 0) {
                summary.container = container
            }
        }
        if Double(summary.container?.length ?? 0) < Double(summary.length) * 0.8 {
            summary.container = nil
        }
        if summary.container == nil, summary.paragraphs >= 2, summary.length >= 200,
           ["div", "section", "td"].contains(name) {
            summary.container = (self, summary.length)
        }
        return summary
    }

    private var proseLength: Int {
        if type == XML_TEXT_NODE {
            return text.trimmingCharacters(in: .whitespacesAndNewlines).count
        }
        guard type == XML_ELEMENT_NODE, name != "a", !isNoise else { return 0 }
        return children.reduce(0) { $0 + $1.proseLength }
    }

    func firstDescendant(named name: String) -> HTMLNode? {
        for child in children where child.type == XML_ELEMENT_NODE && !child.isNoise {
            if child.name == name { return child }
            if let match = child.firstDescendant(named: name) { return match }
        }
        return nil
    }
}
