//
//  GitHubTheme.swift
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
        
        style.foregroundColor = PlatformColor(hex: "#24292e")
        style.backgroundColor = PlatformColor(hex: "#ffffff")

        style.styles["keyword"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#d73a49"))
        style.styles["doctag"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#d73a49"))
        style.styles["template-tag"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#d73a49"))
        style.styles["template-variable"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#d73a49"))
        style.styles["type"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#d73a49"))
        style.styles["variable.language"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#d73a49"))
        style.styles["title"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#6f42c1"))
        style.styles["class"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#6f42c1"))
        style.styles["function"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#6f42c1"))
        style.styles["attr"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["attribute"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["literal"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["meta"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["number"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["operator"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["variable"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["selector-attr"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["selector-class"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["selector-id"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"))
        style.styles["section"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#005cc5"), traits: [.bold])
        style.styles["string"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#032f62"))
        style.styles["regexp"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#032f62"))
        style.styles["built_in"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#e36209"))
        style.styles["symbol"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#e36209"))
        style.styles["comment"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#6a737d"))
        style.styles["code"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#6a737d"))
        style.styles["formula"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#6a737d"))
        style.styles["name"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#22863a"))
        style.styles["quote"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#22863a"))
        style.styles["selector-tag"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#22863a"))
        style.styles["selector-pseudo"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#22863a"))
        style.styles["tag"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#22863a"))
        style.styles["subst"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#24292e"))
        style.styles["bullet"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#735c0f"))
        style.styles["emphasis"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#24292e"), traits: [.italic])
        style.styles["strong"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#24292e"), traits: [.bold])
        style.styles["addition"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#22863a"))
        style.styles["deletion"] = HighlightStyle.TextStyle(color: PlatformColor(hex: "#b31d28"))
        
        return style
    }
}
