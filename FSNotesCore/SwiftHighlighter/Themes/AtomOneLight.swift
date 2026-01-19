//
//  AtomOneLight.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 01.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct AtomOneLightTheme {
    static func make() -> HighlightStyle {
        var style = HighlightStyle()

        style.font = UserDefaultsManagement.codeFont

        // .hljs
        style.foregroundColor = PlatformColor(hex: "#383a42")
        style.backgroundColor = PlatformColor(hex: "#fafafa")

        // .hljs-comment, .hljs-quote (italic)
        style.styles["comment"] = .init(
            color: PlatformColor(hex: "#a0a1a7"),
            traits: [.italic]
        )
        style.styles["quote"] = .init(
            color: PlatformColor(hex: "#a0a1a7"),
            traits: [.italic]
        )

        // .hljs-doctag, .hljs-keyword, .hljs-formula
        style.styles["keyword"] = .init(color: PlatformColor(hex: "#a626a4"))
        style.styles["formula"] = .init(color: PlatformColor(hex: "#a626a4"))

        // .hljs-section, .hljs-name, .hljs-selector-tag, .hljs-deletion, .hljs-subst
        style.styles["section"]  = .init(color: PlatformColor(hex: "#e45649"))
        style.styles["name"]     = .init(color: PlatformColor(hex: "#e45649"))
        style.styles["tag"]      = .init(color: PlatformColor(hex: "#e45649"))
        style.styles["deletion"] = .init(color: PlatformColor(hex: "#e45649"))
        style.styles["subst"]    = .init(color: PlatformColor(hex: "#e45649"))

        // .hljs-literal
        style.styles["literal"] = .init(color: PlatformColor(hex: "#0184bb"))

        // .hljs-string, .hljs-regexp, .hljs-addition, .hljs-attribute, .hljs-meta-string
        style.styles["string"]    = .init(color: PlatformColor(hex: "#50a14f"))
        style.styles["regexp"]    = .init(color: PlatformColor(hex: "#50a14f"))
        style.styles["addition"]  = .init(color: PlatformColor(hex: "#50a14f"))
        style.styles["attribute"] = .init(color: PlatformColor(hex: "#50a14f"))

        // .hljs-built_in, .hljs-class .hljs-title
        style.styles["built_in"] = .init(color: PlatformColor(hex: "#c18401"))
        style.styles["class"]    = .init(color: PlatformColor(hex: "#c18401"))

        // .hljs-attr, .hljs-variable, .hljs-template-variable,
        // .hljs-type, .hljs-selector-class, .hljs-number
        style.styles["attr"]     = .init(color: PlatformColor(hex: "#986801"))
        style.styles["variable"] = .init(color: PlatformColor(hex: "#986801"))
        style.styles["type"]     = .init(color: PlatformColor(hex: "#986801"))
        style.styles["number"]   = .init(color: PlatformColor(hex: "#986801"))

        // .hljs-symbol, .hljs-bullet, .hljs-link, .hljs-meta, .hljs-selector-id, .hljs-title
        style.styles["symbol"] = .init(color: PlatformColor(hex: "#4078f2"))
        style.styles["bullet"] = .init(color: PlatformColor(hex: "#4078f2"))
        style.styles["link"]   = .init(color: PlatformColor(hex: "#4078f2"))
        style.styles["meta"]   = .init(color: PlatformColor(hex: "#4078f2"))
        style.styles["id"]     = .init(color: PlatformColor(hex: "#4078f2"))
        style.styles["title"]  = .init(color: PlatformColor(hex: "#4078f2"))

        // emphasis / strong
        style.styles["emphasis"] = .init(
            color: PlatformColor(hex: "#e45649"), traits: [.italic]
        )

        style.styles["strong"] = .init(
            color: PlatformColor(hex: "#e45649"), traits: [.bold]
        )

        return style
    }
}
