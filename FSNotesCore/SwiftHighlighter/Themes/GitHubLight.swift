//
//  GthubTheme.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 31.08.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

#if os(OSX)
import AppKit
#else
import UIKit
#endif

struct GitHubLightTheme {
    static func make() -> HighlightStyle {
        var style = HighlightStyle()
        style.font = UserDefaultsManagement.codeFont
        
        style.foregroundColor = UserDefaultsManagement.fontColor
        style.backgroundColor = PlatformColor(hex: "#F1F1F1")

        style.styles["keyword"]   = HighlightStyle.TextStyle(color: PlatformColor(hex: "#333333"), traits: [.bold])
        style.styles["string"]    = HighlightStyle.TextStyle(color: PlatformColor(hex: "#dd1144"))
        style.styles["number"]    = HighlightStyle.TextStyle(color: PlatformColor(hex: "#008080"))
        style.styles["comment"]   = HighlightStyle.TextStyle(color: PlatformColor(hex: "#999988"), traits: [.italic])
        style.styles["literal"]   = HighlightStyle.TextStyle(color: PlatformColor(hex: "#008080"))
        style.styles["variable"]  = HighlightStyle.TextStyle(color: PlatformColor(hex: "#008080"))
        style.styles["modifier"]  = HighlightStyle.TextStyle(color: PlatformColor(hex: "#333333"), traits: [.bold])

        style.styles["function"]  = HighlightStyle.TextStyle(color: PlatformColor(hex: "#990000"), traits: [.bold])
        style.styles["class"]     = HighlightStyle.TextStyle(color: PlatformColor(hex: "#0066cc"), traits: [.bold])
        style.styles["params"]    = HighlightStyle.TextStyle(color: PlatformColor(hex: "#795da3"))

        style.styles["built_in"]  = HighlightStyle.TextStyle(color: PlatformColor(hex: "#0086b3"), traits: [.bold])
        style.styles["type"]      = HighlightStyle.TextStyle(color: PlatformColor(hex: "#458"))

        style.styles["operator"]  = HighlightStyle.TextStyle(color: PlatformColor(hex: "#333333"))
        style.styles["punctuation"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#333333"))

        style.styles["meta"]      = HighlightStyle.TextStyle(color: PlatformColor(hex: "#BAB8B8"))
        style.styles["subst"]     = HighlightStyle.TextStyle(color: PlatformColor(hex: "#333333"))

        style.styles["attribute"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#0086b3"))
        style.styles["symbol"]    = HighlightStyle.TextStyle(color: PlatformColor(hex: "#990073"))
        style.styles["regexp"]    = HighlightStyle.TextStyle(color: PlatformColor(hex: "#009926"))
        style.styles["link"]      = HighlightStyle.TextStyle(color: PlatformColor(hex: "#0066cc"))
        style.styles["tag"]       = HighlightStyle.TextStyle(color: PlatformColor(hex: "#000080"))
        style.styles["name"]      = HighlightStyle.TextStyle(color: PlatformColor(hex: "#0066cc"))
        style.styles["quote"]     = HighlightStyle.TextStyle(color: PlatformColor(hex: "#dd1144"))
        style.styles["deletion"]  = HighlightStyle.TextStyle(color: PlatformColor(hex: "#bd2c00"))
        style.styles["addition"]  = HighlightStyle.TextStyle(color: PlatformColor(hex: "#55a532"))
        style.styles["strong"]    = HighlightStyle.TextStyle(color: PlatformColor(hex: "#333333"), traits: [.bold])
        style.styles["emphasis"]  = HighlightStyle.TextStyle(color: PlatformColor(hex: "#333333"), traits: [.italic])

        return style
    }
}
