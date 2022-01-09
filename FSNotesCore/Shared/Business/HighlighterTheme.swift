//
//  HighlighterTheme.swift
//  FSNotes
//
//  Created by Александр on 09.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

enum HighlighterTheme: String {
    case github = "github"
    case solarizedLight = "solarized-light"
    case solarizedDark = "solarized-dark"
    case visualStudio = "vs"
    case atomOneLight = "atom-one-light"
    case atomOneDark = "atom-one-dark"
    case monokaiSublime = "monokai-sublime"
    case xcode = "xcode"
    case zenburn = "zenburn"
    case tomorrow = "tomorrow"
    case agate = "agate"

    static func named(rawValue: String) -> HighlighterTheme {
        switch rawValue {
        case "github": return .github
        case "solarized-light": return .solarizedLight
        case "solarized-dark": return .solarizedDark
        case "vs": return .visualStudio
        case "atom-one-light": return .atomOneLight
        case "atom-one-dark": return .atomOneDark
        case "monokai-sublime": return .monokaiSublime
        case "xcode": return .xcode
        case "zendburn": return .zenburn
        case "tomorrow": return .tomorrow
        case "agate": return .agate
        default: return .github
        }
    }

    public var backgroundHex: String {
        switch self {
        case .github: return "#f8f8f8"
        case .solarizedLight: return "#fdf6e3"
        case .solarizedDark: return "#002b36"
        case .visualStudio: return "#f8f8f8"
        case .atomOneLight: return "#fafafa"
        case .atomOneDark: return "#282c34"
        case .monokaiSublime: return "#23241f"
        case .xcode: return "#f8f8f8"
        case .zenburn: return "#3f3f3f"
        case .tomorrow: return "#f8f8f8"
        case .agate: return "#333333"
        }
    }
}
