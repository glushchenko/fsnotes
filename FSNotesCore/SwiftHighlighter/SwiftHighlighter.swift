import Foundation
#if os(OSX)
import AppKit
#else
import UIKit
#endif

// MARK: - Core Types

public protocol LanguageDefinition {
    var name: String { get }
    var aliases: [String]? { get }
    var keywords: [String: [String]]? { get }
    var contains: [Mode] { get }
    var caseInsensitive: Bool { get }
}

public struct Mode {
    var scope: String?
    var begin: String?
    var end: String?
    var keywords: [String: [String]]?
    var contains: [Mode]?

    private var _beginRegex: NSRegularExpression?
    private var _endRegex: NSRegularExpression?

    public init(
        scope: String? = nil,
        begin: String? = nil,
        end: String? = nil,
        keywords: [String: [String]]? = nil,
        contains: [Mode]? = nil
    ) {
        self.scope = scope
        self.begin = begin
        self.end = end
        self.keywords = keywords
        self.contains = contains

        if let begin = begin {
            self._beginRegex = try? NSRegularExpression(pattern: begin, options: [])
        }
        if let end = end {
            self._endRegex = try? NSRegularExpression(pattern: end, options: [])
        }
    }

    var beginRegex: NSRegularExpression? { _beginRegex }
    var endRegex: NSRegularExpression? { _endRegex }
}

public struct Match {
    let range: Range<String.Index>
    let scope: String
    let text: String
}

extension Match {
    var substring: Substring {
        text[range]
    }

    var nsRange: NSRange {
        NSRange(range, in: text)
    }
}

// MARK: - Highlight Style

public struct HighlightStyle {
    public struct TextStyle {
        public var color: PlatformColor
        public var traits: FontTraits = []
    }

    public var font: PlatformFont = PlatformFont.systemFont(ofSize: 14)
    public var foregroundColor: PlatformColor = .black
    public var backgroundColor: PlatformColor = .white
    public var styles: [String: TextStyle] = [:]

    public init() {}

    public func attributes(for scope: String) -> [NSAttributedString.Key: Any] {
        guard let style = styles[scope] else {
            return [.font: font, .foregroundColor: PlatformColor.label]
        }

        let customFont = PlatformFont.withTraits(font: font, traits: style.traits)
        return [.font: customFont, .foregroundColor: style.color]
    }
}

// MARK: - Renderer

class AttributedStringRenderer {
    private let style: HighlightStyle
    private let baseAttributes: [NSAttributedString.Key: Any]

    init(style: HighlightStyle = HighlightStyle()) {
        self.style = style
        self.baseAttributes = [
            .font: style.font,
            .foregroundColor: PlatformColor.label
        ]
    }

    func render(text: String, matches: [Match]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text, attributes: baseAttributes)
        let sortedMatches = matches.sorted { $0.range.lowerBound < $1.range.lowerBound }

        for match in sortedMatches {
            let nsRange = match.nsRange
            if nsRange.location + nsRange.length <= attributedString.length {
                attributedString.addAttributes(style.attributes(for: match.scope), range: nsRange)
            }
        }
        return attributedString
    }

    func apply(matches: [Match], to textStorage: NSMutableAttributedString, offset: Int) {
        let sortedMatches = matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
        for match in sortedMatches {
            let nsRange = match.nsRange
            let convertedRange = NSRange(location: offset + nsRange.location, length: nsRange.length)
            if convertedRange.location + convertedRange.length <= textStorage.length {
                textStorage.addAttributes(style.attributes(for: match.scope), range: convertedRange)
            }
        }
    }
}

// MARK: - Swift Highlighter

public class SwiftHighlighter {
    private static var languages: [String: LanguageDefinition] = [:]

    private var aliases: [String: String] = [:]
    private var renderer: AttributedStringRenderer
    public var options: Options

    public struct Options {
        public var style: HighlightStyle = HighlightStyle()
        public static let `default` = Options()

        public init(style: HighlightStyle = HighlightStyle()) {
            self.style = style
        }
    }

    public init(options: Options = .default) {
        self.options = options
        self.renderer = AttributedStringRenderer(style: options.style)

        if SwiftHighlighter.languages.isEmpty {
            self.registerLanguage("swift", definition: SwiftLanguage())
            self.registerLanguage("php", definition: PHPLanguage())
            self.registerLanguage("javascript", definition: JavaScriptLanguage())
            self.registerLanguage("sql", definition: SQLLanguage())
            self.registerLanguage("python", definition: PythonLanguage())
            self.registerLanguage("c", definition: CLanguage())
            self.registerLanguage("cpp", definition: CPlusPlusLanguage())
            self.registerLanguage("java", definition: JavaLanguage())
            self.registerLanguage("go", definition: GoLanguage())
            self.registerLanguage("rust", definition: RustLanguage())
            self.registerLanguage("csharp", definition: CSharpLanguage())
            self.registerLanguage("kotlin", definition: KotlinLanguage())
            self.registerLanguage("r", definition: RLanguage())
            self.registerLanguage("ruby", definition: RubyLanguage())
            self.registerLanguage("matlab", definition: MatlabLanguage())
            self.registerLanguage("dart", definition: DartLanguage())
            self.registerLanguage("vb", definition: VisualBasicLanguage())
            self.registerLanguage("assembly", definition: AssemblyLanguage())
            self.registerLanguage("scratch", definition: ScratchLanguage())
            self.registerLanguage("groovy", definition: GroovyLanguage())
            self.registerLanguage("objectivec", definition: ObjectiveCLanguage())
        }
    }

    public func getLanguages() -> [String] {
        Array(SwiftHighlighter.languages.keys)
    }

    public func updateStyle(_ style: HighlightStyle) {
        self.options.style = style
        self.renderer = AttributedStringRenderer(style: style)
    }

    public func registerLanguage(_ name: String, definition: LanguageDefinition) {
        SwiftHighlighter.languages[name.lowercased()] = definition
        if let aliases = definition.aliases {
            for alias in aliases { self.aliases[alias.lowercased()] = name.lowercased() }
        }
    }

    public func getLanguage(_ name: String) -> LanguageDefinition? {
        let lower = name.lowercased()
        return SwiftHighlighter.languages[lower] ?? SwiftHighlighter.languages[aliases[lower] ?? ""]
    }

    public func highlight(_ code: String, language: String) -> NSAttributedString {
        guard let langDef = getLanguage(language) else {
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: options.style.font,
                .foregroundColor: PlatformColor.label
            ]
            return NSAttributedString(string: code, attributes: baseAttrs)
        }
        let matches = processLanguage(langDef, text: code)
        return renderer.render(text: code, matches: matches)
    }

    private func processLanguage(_ language: LanguageDefinition, text: String) -> [Match] {
        var matches: [Match] = []
        var protectedRanges: [Range<String.Index>] = []

        for mode in language.contains {
            let modeMatches = processMode(mode, text: text, searchRange: text.startIndex..<text.endIndex, parentScope: nil)
            for modeMatch in modeMatches {
                if !protectedRanges.contains(where: { $0.overlaps(modeMatch.range) }) {
                    matches.append(modeMatch)
                }
            }

            protectedRanges.append(contentsOf: modeMatches
                .filter { ["comment", "string", "comment.doc", "subst"].contains($0.scope) }
                .map { $0.range })
        }

        if let keywords = language.keywords {
            for (scope, words) in keywords {
                for word in words {
                    let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
                    let options: NSRegularExpression.Options = language.caseInsensitive ? [.caseInsensitive] : []
                    if let regex = try? NSRegularExpression(pattern: pattern, options: options) {
                        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                        for m in regex.matches(in: text, range: nsRange) {
                            if let range = Range(m.range, in: text),
                               !protectedRanges.contains(where: { $0.overlaps(range) }) {
                                matches.append(Match(range: range, scope: scope, text: text))
                            }
                        }
                    }
                }
            }
        }

        return matches
    }

    private func processMode(
        _ mode: Mode,
        text: String,
        searchRange: Range<String.Index>,
        parentScope: String?
    ) -> [Match] {
        var matches: [Match] = []
        var currentIndex = searchRange.lowerBound

        while currentIndex < searchRange.upperBound {
            guard let regex = mode.beginRegex else { break }

            let nsSearchRange = NSRange(currentIndex..<searchRange.upperBound, in: text)
            guard let match = regex.firstMatch(in: text, range: nsSearchRange),
                  let matchRange = Range(match.range, in: text)
            else { break }

            var matchEnd = matchRange.upperBound

            if let endRegex = mode.endRegex {
                let nsEndRange = NSRange(matchEnd..<searchRange.upperBound, in: text)
                if let endMatch = endRegex.firstMatch(in: text, range: nsEndRange),
                   let endRange = Range(endMatch.range, in: text) {
                    matchEnd = endRange.upperBound
                }
            }

            let finalRange = matchRange.lowerBound..<matchEnd

            if let scope = mode.scope {
                matches.append(Match(range: finalRange, scope: scope, text: text))
            }

            if let children = mode.contains {
                for child in children {
                    let childMatches = processMode(child, text: text, searchRange: finalRange, parentScope: mode.scope ?? parentScope)
                    matches.append(contentsOf: childMatches)
                }
            }

            currentIndex = finalRange.upperBound
        }

        return matches
    }

    public func highlight(in attributedString: NSMutableAttributedString, range: NSRange, language: String? = nil, skipTicks: Bool = false) {
        guard let plainRange = Range(range, in: attributedString.string) else { return }
        guard let language = language, let langDef = getLanguage(language) else { return }

        let substring = String(attributedString.string[plainRange])

        // Reset code font
        attributedString.addAttributes([
            .font: options.style.font,
            .foregroundColor: options.style.foregroundColor
        ], range: range)

        let matches = processLanguage(langDef, text: substring)
        renderer.apply(matches: matches, to: attributedString, offset: range.location)

        attributedString.fixAttributes(in: range)

        // Highlight back ticks
        if !skipTicks {
            let  color = Color.init(red: 0.18, green: 0.61, blue: 0.25, alpha: 1.00)
            let langRange = NSRange(location: range.location + 3, length: language.count)
            attributedString.addAttribute(.foregroundColor, value: color, range: langRange)

            // Open range font and foreground
            let openRange = NSRange(location: range.location, length: 3)
            attributedString.addAttribute(.foregroundColor, value: Color.lightGray, range: openRange)
            attributedString.addAttribute(.font, value: NotesTextProcessor.codeFont, range: openRange)

            // Close range foreground
            let closeRange = NSRange(location: range.upperBound - 4, length: 4)
            attributedString.addAttribute(.foregroundColor, value: Color.lightGray, range: closeRange)
        }
    }
}

// MARK: - Common Modes

public struct CommonModes {
    public static let stringDouble = Mode(scope: "string", begin: "\"(?:[^\"\\\\]|\\\\.)*\"")
    public static let stringSingle = Mode(scope: "string", begin: "'(?:[^'\\\\]|\\\\.)*'")
    public static let number = Mode(scope: "number", begin: "\\b\\d+(?:\\.\\d+)?\\b")
    public static func comment(begin: String, end: String? = nil) -> Mode {
        Mode(scope: "comment", begin: begin + (end != nil ? ".*?\(end!)" : ".*$"))
    }
}
