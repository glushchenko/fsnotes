//
//  AtomOneDark.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 01.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct AtomOneDarkTheme {
    static func make() -> HighlightStyle {
        var style = HighlightStyle()

        style.font = UserDefaultsManagement.codeFont

        // .hljs
        style.foregroundColor = PlatformColor(hex: "#abb2bf")
        style.backgroundColor = PlatformColor(hex: "#282c34")

        // .hljs-comment, .hljs-quote (italic)
        style.styles["comment"] = .init(
            color: PlatformColor(hex: "#5c6370"),
            traits: [.italic]
        )
        style.styles["quote"] = .init(
            color: PlatformColor(hex: "#5c6370"),
            traits: [.italic]
        )

        // .hljs-doctag, .hljs-keyword, .hljs-formula
        style.styles["keyword"] = .init(color: PlatformColor(hex: "#c678dd"))
        style.styles["formula"] = .init(color: PlatformColor(hex: "#c678dd"))

        // .hljs-section, .hljs-name, .hljs-selector-tag, .hljs-deletion, .hljs-subst
        style.styles["section"]  = .init(color: PlatformColor(hex: "#e06c75"))
        style.styles["name"]     = .init(color: PlatformColor(hex: "#e06c75"))
        style.styles["tag"]      = .init(color: PlatformColor(hex: "#e06c75"))
        style.styles["deletion"] = .init(color: PlatformColor(hex: "#e06c75"))
        style.styles["subst"]    = .init(color: PlatformColor(hex: "#e06c75"))

        // .hljs-literal
        style.styles["literal"] = .init(color: PlatformColor(hex: "#56b6c2"))

        // .hljs-string, .hljs-regexp, .hljs-addition, .hljs-attribute, .hljs-meta-string
        style.styles["string"]    = .init(color: PlatformColor(hex: "#98c379"))
        style.styles["regexp"]    = .init(color: PlatformColor(hex: "#98c379"))
        style.styles["addition"]  = .init(color: PlatformColor(hex: "#98c379"))
        style.styles["attribute"] = .init(color: PlatformColor(hex: "#98c379"))

        // .hljs-built_in, .hljs-class .hljs-title
        style.styles["built_in"] = .init(color: PlatformColor(hex: "#e6c07b"))
        style.styles["class"]    = .init(color: PlatformColor(hex: "#e6c07b"))

        // .hljs-attr, .hljs-variable, .hljs-template-variable,
        // .hljs-type, .hljs-selector-class, .hljs-number
        style.styles["attr"]     = .init(color: PlatformColor(hex: "#d19a66"))
        style.styles["variable"] = .init(color: PlatformColor(hex: "#d19a66"))
        style.styles["type"]     = .init(color: PlatformColor(hex: "#d19a66"))
        style.styles["number"]   = .init(color: PlatformColor(hex: "#d19a66"))

        // .hljs-symbol, .hljs-bullet, .hljs-link, .hljs-meta, .hljs-selector-id, .hljs-title
        style.styles["symbol"] = .init(color: PlatformColor(hex: "#61aeee"))
        style.styles["bullet"] = .init(color: PlatformColor(hex: "#61aeee"))
        style.styles["link"]   = .init(color: PlatformColor(hex: "#61aeee"))
        style.styles["meta"]  = .init(color: PlatformColor(hex: "#61aeee"))
        style.styles["id"]    = .init(color: PlatformColor(hex: "#61aeee"))
        style.styles["title"] = .init(color: PlatformColor(hex: "#61aeee"))

        // emphasis / strong
        style.styles["emphasis"] = .init(
            color: PlatformColor(hex: "#e06c75"), traits: [.italic]
        )
        style.styles["strong"] = .init(
            color: PlatformColor(hex: "#e06c75"), traits: [.bold]
        )

        return style
    }
}
