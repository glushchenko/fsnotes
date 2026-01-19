//
//  SolarizedLight.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 01.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct SolarizedLightTheme {
    static func make() -> HighlightStyle {
        var style = HighlightStyle()

        style.font = UserDefaultsManagement.codeFont

        // .hljs
        style.foregroundColor = PlatformColor(hex: "#657b83")
        style.backgroundColor = PlatformColor(hex: "#fdf6e3")

        // .hljs-comment, .hljs-quote
        style.styles["comment"] = .init(color: PlatformColor(hex: "#93a1a1"))
        style.styles["quote"]   = .init(color: PlatformColor(hex: "#93a1a1"))

        // .hljs-keyword, .hljs-selector-tag, .hljs-addition
        style.styles["keyword"]  = .init(color: PlatformColor(hex: "#859900"))
        style.styles["tag"]      = .init(color: PlatformColor(hex: "#859900"))
        style.styles["addition"] = .init(color: PlatformColor(hex: "#859900"))

        // .hljs-number, .hljs-string, .hljs-literal, .hljs-regexp
        style.styles["number"]  = .init(color: PlatformColor(hex: "#2aa198"))
        style.styles["string"]  = .init(color: PlatformColor(hex: "#2aa198"))
        style.styles["literal"] = .init(color: PlatformColor(hex: "#2aa198"))
        style.styles["regexp"]  = .init(color: PlatformColor(hex: "#2aa198"))

        // .hljs-title, .hljs-section, .hljs-name
        style.styles["function"] = .init(color: PlatformColor(hex: "#268bd2"))
        style.styles["section"]  = .init(color: PlatformColor(hex: "#268bd2"))
        style.styles["name"]     = .init(color: PlatformColor(hex: "#268bd2"))
        style.styles["class"]    = .init(color: PlatformColor(hex: "#268bd2"))

        // .hljs-attribute, .hljs-variable, .hljs-type
        style.styles["attribute"] = .init(color: PlatformColor(hex: "#b58900"))
        style.styles["variable"]  = .init(color: PlatformColor(hex: "#b58900"))
        style.styles["type"]      = .init(color: PlatformColor(hex: "#b58900"))

        // .hljs-symbol, .hljs-bullet, .hljs-subst, .hljs-meta, .hljs-link
        style.styles["symbol"]  = .init(color: PlatformColor(hex: "#cb4b16"))
        style.styles["bullet"]  = .init(color: PlatformColor(hex: "#cb4b16"))
        style.styles["subst"]   = .init(color: PlatformColor(hex: "#cb4b16"))
        style.styles["meta"]    = .init(color: PlatformColor(hex: "#cb4b16"))
        style.styles["link"]    = .init(color: PlatformColor(hex: "#cb4b16"))

        // .hljs-built_in, .hljs-deletion
        style.styles["built_in"] = .init(color: PlatformColor(hex: "#dc322f"))
        style.styles["deletion"] = .init(color: PlatformColor(hex: "#dc322f"))

        // font styles
        style.styles["emphasis"] = .init(
            color: PlatformColor(hex: "#cb4b16"), traits: [.italic]
        )

        style.styles["strong"] = .init(
            color: PlatformColor(hex: "#cb4b16"), traits: [.bold]
        )

        return style
    }
}
