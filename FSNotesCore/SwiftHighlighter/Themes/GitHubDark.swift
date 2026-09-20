//
//  GitHubDark.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 01.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct GitHubDarkTheme {
    static func make() -> HighlightStyle {
        var style = HighlightStyle()

        style.font = UserDefaultsManagement.codeFont

        // .hljs { color, background }
        style.foregroundColor = PlatformColor(hex: "#F1F1F1")
        style.backgroundColor = PlatformColor(hex: "#232520")

        // .hljs-keyword, .hljs-type, .hljs-template-*, .hljs-doctag
        style.styles["keyword"]   = .init(color: PlatformColor(hex: "#ff7b72"))
        style.styles["type"]      = .init(color: PlatformColor(hex: "#ff7b72"))
        style.styles["modifier"]  = .init(color: PlatformColor(hex: "#ff7b72"))

        // .hljs-title (function, class)
        style.styles["function"]  = .init(color: PlatformColor(hex: "#d2a8ff"))
        style.styles["class"]     = .init(color: PlatformColor(hex: "#d2a8ff"))

        // .hljs-attr, .hljs-literal, .hljs-number, .hljs-variable, etc
        style.styles["attribute"] = .init(color: PlatformColor(hex: "#79c0ff"))
        style.styles["literal"]   = .init(color: PlatformColor(hex: "#79c0ff"))
        style.styles["number"]    = .init(color: PlatformColor(hex: "#79c0ff"))
        style.styles["variable"]  = .init(color: PlatformColor(hex: "#79c0ff"))
        style.styles["operator"]  = .init(color: PlatformColor(hex: "#79c0ff"))
        style.styles["meta"]      = .init(color: PlatformColor(hex: "#79c0ff"))

        // .hljs-string, .hljs-regexp
        style.styles["string"]    = .init(color: PlatformColor(hex: "#a5d6ff"))
        style.styles["regexp"]    = .init(color: PlatformColor(hex: "#a5d6ff"))
        style.styles["quote"]     = .init(color: PlatformColor(hex: "#a5d6ff"))

        // .hljs-built_in, .hljs-symbol
        style.styles["built_in"]  = .init(color: PlatformColor(hex: "#ffa657"))
        style.styles["symbol"]    = .init(color: PlatformColor(hex: "#ffa657"))

        // .hljs-comment, .hljs-code, .hljs-formula
        style.styles["comment"]   = .init(
            color: PlatformColor(hex: "#8b949e"),
            traits: [.italic]
        )

        // .hljs-name, .hljs-selector-tag
        style.styles["name"]      = .init(color: PlatformColor(hex: "#7ee787"))
        style.styles["tag"]       = .init(color: PlatformColor(hex: "#7ee787"))

        // .hljs-subst
        style.styles["subst"]     = .init(color: PlatformColor(hex: "#c9d1d9"))

        // .hljs-section
        style.styles["section"]   = .init(
            color: PlatformColor(hex: "#1f6feb"),
            traits: [.bold]
        )

        // .hljs-bullet
        style.styles["bullet"]    = .init(color: PlatformColor(hex: "#f2cc60"))

        // .hljs-emphasis
        style.styles["emphasis"]  = .init(
            color: PlatformColor(hex: "#c9d1d9"),
            traits: [.italic]
        )

        // .hljs-strong
        style.styles["strong"]    = .init(
            color: PlatformColor(hex: "#c9d1d9"),
            traits: [.bold]
        )

        // .hljs-addition
        style.styles["addition"]  = .init(
            color: PlatformColor(hex: "#aff5b4"),
        )

        // .hljs-deletion
        style.styles["deletion"]  = .init(
            color: PlatformColor(hex: "#ffdcd7"),
        )

        // punctuation / params / property — deliberately default
        style.styles["punctuation"] = .init(color: PlatformColor(hex: "#79c0ff"))
        style.styles["params"]      = .init(color: PlatformColor(hex: "#79c0ff"))
        style.styles["property"]    = .init(color: PlatformColor(hex: "#79c0ff"))

        return style
    }
}

