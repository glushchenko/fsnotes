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
            self._beginRegex = try? NSRegularExpression(pattern: begin, options: [.anchorsMatchLines])
        }
        
        if let end = end {
            self._endRegex = try? NSRegularExpression(pattern: end, options: [.anchorsMatchLines])
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
            self.registerLanguage("cpp", definition: CppLanguage())
            self.registerLanguage("java", definition: JavaLanguage())
            self.registerLanguage("go", definition: GoLanguage())
            self.registerLanguage("rust", definition: RustLanguage())
            self.registerLanguage("csharp", definition: CSharpLanguage())
            self.registerLanguage("kotlin", definition: KotlinLanguage())
            self.registerLanguage("r", definition: RLanguage())
            self.registerLanguage("ruby", definition: RubyLanguage())
            self.registerLanguage("matlab", definition: MatlabLanguage())
            self.registerLanguage("dart", definition: DartLanguage())
            self.registerLanguage("vb", definition: VbLanguage())
            self.registerLanguage("assembly", definition: AssemblyLanguage())
            self.registerLanguage("scratch", definition: ScratchLanguage())
            self.registerLanguage("groovy", definition: GroovyLanguage())
            self.registerLanguage("objectivec", definition: ObjectiveCLanguage())
            self.registerLanguage("scala", definition: ScalaLanguage())
            self.registerLanguage("bash", definition: BashLanguage())
            self.registerLanguage("haskell", definition: HaskellLanguage())
            self.registerLanguage("erlang", definition: ErlangLanguage())
            self.registerLanguage("perl", definition: PerlLanguage())
            self.registerLanguage("lua", definition: LuaLanguage())
            self.registerLanguage("clojure", definition: ClojureLanguage())
            self.registerLanguage("html", definition: HTMLLanguage())
            self.registerLanguage("css", definition: CSSLanguage())
            self.registerLanguage("sh", definition: ShellLanguage())
            self.registerLanguage("ts", definition: TypeScriptLanguage())
            self.registerLanguage("lisp", definition: LispLanguage())
            
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
            let modeMatches = processMode(
                mode,
                text: text,
                searchRange: text.startIndex..<text.endIndex,
                protectedRanges: protectedRanges
            )
            
            for modeMatch in modeMatches {
                if !protectedRanges.contains(where: { $0.overlaps(modeMatch.range) }) {
                    matches.append(modeMatch)
                    if ["comment", "string", "comment.doc", "subst"].contains(modeMatch.scope) {
                        protectedRanges.append(modeMatch.range)
                    }
                }
            }
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
        protectedRanges: [Range<String.Index>] = []
    ) -> [Match] {
        var matches: [Match] = []
        var currentIndex = searchRange.lowerBound

        while currentIndex < searchRange.upperBound {
            guard let regex = mode.beginRegex else { break }

            let nsSearchRange = NSRange(currentIndex..<searchRange.upperBound, in: text)
            guard let match = regex.firstMatch(in: text, range: nsSearchRange),
                  let matchRange = Range(match.range, in: text)
            else { break }

            if protectedRanges.contains(where: { $0.contains(matchRange.lowerBound) }) {
                if let protectedRange = protectedRanges.first(where: { $0.contains(matchRange.lowerBound) }) {
                    currentIndex = protectedRange.upperBound
                } else {
                    currentIndex = text.index(after: matchRange.lowerBound)
                }
                continue
            }

            var matchEnd = matchRange.upperBound

            if let endRegex = mode.endRegex {
                let nsEndRange = NSRange(matchEnd..<searchRange.upperBound, in: text)
                if let endMatch = endRegex.firstMatch(in: text, range: nsEndRange),
                   let endRange = Range(endMatch.range, in: text) {
                    
                    if mode.scope == "comment" && mode.end == "\n" {
                        matchEnd = endRange.lowerBound
                    } else {
                        matchEnd = endRange.upperBound
                    }
                }
            }

            let finalRange = matchRange.lowerBound..<matchEnd

            if let scope = mode.scope {
                matches.append(Match(range: finalRange, scope: scope, text: text))
            }

            currentIndex = finalRange.upperBound
        }

        return matches
    }

    public func highlight(
        in attributedString: NSMutableAttributedString,
        fullRange: NSRange,
        editedRange: NSRange? = nil
    ) {
        let language = getLanguage(from: attributedString, startingAt: fullRange.location)
        let langDefinition = language.flatMap { getLanguage($0) }
        let shouldHighlightTicks = editedRange.map { fullRange.location == $0.location } ?? true
        
        var codeRange = calculateCodeRange(
            fullRange: fullRange,
            language: language
        )
        
        // Expand for comments
        if let editedRange = editedRange, editedRange.location != fullRange.location {
            if let result = expandRangeForMultilineConstructs(
                in: attributedString,
                editedRange: editedRange,
                codeRange: codeRange,
                language: langDefinition
            ) {
                codeRange = result
            } else {
                codeRange = editedRange
            }
        }
        
        // Reset formatting (no language)
        attributedString.addAttributes([
            .font: options.style.font,
            .foregroundColor: options.style.foregroundColor
        ], range: codeRange)
        
        // Apply code highlighting
        if let langDefinition = langDefinition,
           codeRange.length > 0,
           let codePlainRange = Range(codeRange, in: attributedString.string) {
            let codeText = String(attributedString.string[codePlainRange])
            let matches = processLanguage(langDefinition, text: codeText)
            renderer.apply(matches: matches, to: attributedString, offset: codeRange.location)
        }
        
        attributedString.fixAttributes(in: codeRange)
        
        // Apply ticks and lang highlighting
        if shouldHighlightTicks {
            highlightCodeBlockDelimiters(
                in: attributedString,
                range: fullRange,
                language: language,
                hasLanguageDefinition: langDefinition != nil
            )
        }
    }

    private func calculateCodeRange(
        fullRange: NSRange,
        language: String?
    ) -> NSRange {
        let codeStartOffset = language.map { 3 + $0.count } ?? 0
        
        return NSRange(
            location: fullRange.location + codeStartOffset,
            length: max(0, fullRange.length - codeStartOffset - 3)
        )
    }

    private func highlightCodeBlockDelimiters(
        in attributedString: NSMutableAttributedString,
        range: NSRange,
        language: String?,
        hasLanguageDefinition: Bool
    ) {
        let grayColor = Color.lightGray
        let greenColor = Color(red: 0.18, green: 0.61, blue: 0.25, alpha: 1.0)
        
        // open ```
        let openRange = NSRange(location: range.location, length: 3)
        attributedString.addAttributes([
            .foregroundColor: grayColor,
            .font: NotesTextProcessor.codeFont
        ], range: openRange)
        
        // lang
        if hasLanguageDefinition, let language = language, !language.isEmpty {
            let langRange = NSRange(location: range.location + 3, length: language.count)
            attributedString.addAttribute(.foregroundColor, value: greenColor, range: langRange)
        }
        
        // close ```
        let closeRange = NSRange(location: range.upperBound - 4, length: 4)
        attributedString.addAttributes([
            .foregroundColor: grayColor,
            .font: NotesTextProcessor.codeFont
        ], range: closeRange)
    }
    
    private func getLanguage(from attributedString: NSMutableAttributedString, startingAt start: Int) -> String? {
        let s = attributedString.string
        guard start >= 0, start < s.count else { return nil }

        let startIndex = s.index(s.startIndex, offsetBy: start)
        let remaining = s[startIndex...]

        // Starts with ```
        guard remaining.hasPrefix("```") else { return nil }

        // Move index by 3
        guard let afterBackticks = s.index(startIndex, offsetBy: 3, limitedBy: s.endIndex) else { return nil }
        
        var index = afterBackticks
        let endIndex = s.endIndex
        
        // Search for language before space or line break
        while index < endIndex, s[index] != "\n", s[index] != " " {
            index = s.index(after: index)
        }
        
        return index == afterBackticks ? nil : String(s[afterBackticks..<index]).trim()
    }
    
    private func expandRangeForMultilineConstructs(
        in attributedString: NSAttributedString,
        editedRange: NSRange,
        codeRange: NSRange,
        language: LanguageDefinition?
    ) -> NSRange? {
        guard let language = language else { return nil }
        
        let multilineModes = language.contains.filter { $0.begin != nil && $0.end != nil }
        guard !multilineModes.isEmpty else { return nil }
        
        var expandedLocation = editedRange.location
        var expandedEnd = editedRange.location + editedRange.length
        
        for mode in multilineModes {
            guard let beginRegex = mode.beginRegex,
                  let endRegex = mode.endRegex else { continue }
            
            let isPaired = mode.begin == mode.end
            let allMatches = beginRegex.matches(in: attributedString.string, range: codeRange)
            
            if isPaired {
                var openMatch: NSTextCheckingResult?
                for match in allMatches {
                    if match.range.location < editedRange.location {
                        openMatch = (openMatch == nil) ? match : nil // toggle
                    } else if openMatch != nil {
                        expandedLocation = min(expandedLocation, openMatch!.range.location)
                        expandedEnd = max(expandedEnd, match.range.location + match.range.length)
                        break
                    }
                }
            } else {
                for beginMatch in allMatches.reversed() {
                    if beginMatch.range.location > editedRange.location + editedRange.length {
                        continue
                    }
                    
                    let searchStart = beginMatch.range.location + beginMatch.range.length
                    let searchEnd = codeRange.location + codeRange.length
                    
                    guard searchEnd > searchStart else { continue }
                    
                    let searchRange = NSRange(
                        location: searchStart,
                        length: searchEnd - searchStart
                    )
                    
                    if let endMatch = endRegex.firstMatch(in: attributedString.string, range: searchRange) {
                        let endMatchEnd = endMatch.range.location + endMatch.range.length
                        
                        if editedRange.location >= beginMatch.range.location &&
                           editedRange.location <= endMatchEnd {
                            expandedLocation = min(expandedLocation, beginMatch.range.location)
                            expandedEnd = max(expandedEnd, endMatchEnd)
                            break
                        }
                    }
                }
            }
        }
        
        // Safe
        expandedLocation = max(expandedLocation, codeRange.location)
        expandedEnd = min(expandedEnd, codeRange.location + codeRange.length)
        
        guard expandedEnd > expandedLocation,
              expandedLocation != editedRange.location || expandedEnd != editedRange.location + editedRange.length else {
            return nil
        }
        
        return NSRange(location: expandedLocation, length: expandedEnd - expandedLocation)
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
