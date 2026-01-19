//
//  MermaidLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct MermaidLanguage: LanguageDefinition {
    let name = "Mermaid"
    let aliases: [String]? = ["mermaid", "mmd"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            // Diagram types
            "graph", "flowchart", "sequenceDiagram", "classDiagram", "stateDiagram",
            "stateDiagram-v2", "erDiagram", "journey", "gantt", "pie", "quadrantChart",
            "requirementDiagram", "gitGraph", "mindmap", "timeline", "zenuml",
            "sankey-beta", "xyChart",
            // Flowchart/Graph directions
            "TB", "TD", "BT", "RL", "LR",
            // Flowchart node types
            "subgraph", "end",
            // Sequence diagram
            "participant", "actor", "activate", "deactivate", "note", "loop", "alt",
            "else", "opt", "par", "and", "rect", "autonumber", "over", "right of",
            "left of", "link", "links",
            // Class diagram
            "class", "namespace", "direction", "link", "click", "callback",
            "cssClass", "style",
            // State diagram
            "state", "note right of", "note left of", "fork", "join", "choice",
            "concurrency",
            // ER diagram
            "entity", "relationship",
            // Gantt
            "title", "dateFormat", "axisFormat", "todayMarker", "excludes", "includes",
            "section", "after", "active", "done", "crit", "milestone",
            // Git graph
            "commit", "branch", "checkout", "merge", "reset", "cherry-pick", "tag",
            "type", "id", "msg", "REVERSE", "HIGHLIGHT",
            // Journey
            "title", "section",
            // Pie
            "title", "showData",
            // Requirement diagram
            "requirement", "functionalRequirement", "interfaceRequirement",
            "performanceRequirement", "physicalRequirement", "designConstraint",
            "element", "contains", "copies", "derives", "satisfies", "verifies",
            "refines", "traces",
            // Styling
            "classDef", "class", "style", "linkStyle", "fill", "stroke", "stroke-width",
            "color", "stroke-dasharray",
            // Configuration
            "%%{init:", "theme", "themeVariables", "logLevel", "securityLevel",
            "startOnLoad", "arrowMarkerAbsolute", "flowchart", "sequence", "gantt",
            // Quadrant chart
            "x-axis", "y-axis", "quadrant-1", "quadrant-2", "quadrant-3", "quadrant-4",
            // Timeline
            "title", "section",
            // XY Chart
            "x-axis", "y-axis", "line", "bar"
        ],
        "literal": ["true", "false", "null"],
        "built_in": [
            // Arrow types for flowchart
            "-->", "---", "-.->", "-.-", "==>", "===", "~~>", "~~~",
            // Arrow types with text
            "-- text -->", "-. text .->", "== text ==>",
            // Sequence diagram arrows
            "->>", "-->>", "->", "-->", "-x", "--x", "-)", "--)", "<<->>", "<<-->>",
            // Class relationships
            "<|--", "*--", "o--", "-->", "..|>", "..", "<--", "--|>",
            // State transitions
            "-->", ":-->",
            // ER relationships
            "||--o{", "}o--||", "||--|{", "}|--||", "o{--||", "||--{o",
            "||..o{", "}o..||", "||..|{", "}|..||", "o{..||", "||..{o",
            // Link text modifiers
            "|text|", "---|text|", "-->|text|",
            // Node shapes (flowchart)
            "()", "[]", "[()]", "[[]]", "[()]", "[([])]", "((()))", ">]", "{}",
            "{{}}", "[//]", "[\\\\]", "[/\\]", "[\\/]",
            // Special characters in text
            "#quot;", "#9829;", "#9830;", "#9827;", "#9824;", "#nbsp;", "#lt;", "#gt;",
            // Styling keywords
            "fill", "stroke", "stroke-width", "color", "fill-opacity", "stroke-opacity",
            "class", "cssClass", "style", "classDef", "linkStyle",
            // Themes
            "default", "forest", "dark", "neutral", "base",
            // Security levels
            "strict", "loose", "antiscript", "sandbox",
            // Log levels
            "debug", "info", "warn", "error", "fatal",
            // Git graph types
            "NORMAL", "REVERSE", "HIGHLIGHT",
            // Journey scores
            "1", "2", "3", "4", "5",
            // ER cardinality
            "zero or one", "one or more", "one or many", "zero or more",
            "only one", "zero or many",
            // Class visibility
            "+", "-", "#", "~",
            // Class annotations
            "<<interface>>", "<<abstract>>", "<<service>>", "<<enumeration>>",
            "<<annotation>>", "<<utility>>", "<<metaclass>>",
            // State types
            "[*]", "<<fork>>", "<<join>>", "<<choice>>",
            // Time formats
            "YYYY-MM-DD", "HH:mm", "HH:mm:ss", "HH:mm:ss.SSS",
            // Axis formats
            "%Y-%m-%d", "%H:%M", "%H:%M:%S", "%d/%m", "%d/%m/%Y",
            // Actions
            "click", "call", "href", "tooltip",
            // Common properties
            "id", "title", "description", "type", "risk", "verifyMethod"
        ]
    ]
    let contains: [Mode] = [
        // Comments
        Mode(scope: "comment", begin: "%%", end: "\n"),
        
        // Block comments (JSON-style config)
        Mode(scope: "comment", begin: "%%\\{", end: "\\}%%"),
        
        // Diagram type declaration
        Mode(scope: "keyword", begin: "^\\s*(?:graph|flowchart|sequenceDiagram|classDiagram|stateDiagram|stateDiagram-v2|erDiagram|journey|gantt|pie|quadrantChart|requirementDiagram|gitGraph|mindmap|timeline|zenuml|sankey-beta|xyChart)\\b"),
        
        // Subgraph
        Mode(scope: "class", begin: "\\bsubgraph\\s+([a-zA-Z0-9_]+)"),
        
        // Node IDs (various formats)
        Mode(scope: "meta", begin: "\\b[a-zA-Z][a-zA-Z0-9_-]*\\b"),
        
        // Strings with double quotes
        CommonModes.stringDouble,
        
        // Strings with single quotes (for labels)
        CommonModes.stringSingle,
        
        // Strings with backticks (for special characters)
        Mode(scope: "string", begin: "`", end: "`"),
        
        // Node text in square brackets
        Mode(scope: "string", begin: "\\[", end: "\\]"),
        
        // Node text in round brackets
        Mode(scope: "string", begin: "\\(", end: "\\)"),
        
        // Node text in curly brackets
        Mode(scope: "string", begin: "\\{", end: "\\}"),
        
        // Arrow types
        Mode(scope: "keyword", begin: "(?:-->|---|-.->|-.-|==>|===|~~>|~~~|->>|-->>|->|-->|-x|--x|-\\)|--\\)|<<->>|<<-->>)"),
        
        // Class relationships
        Mode(scope: "keyword", begin: "(?:<\\|--|\\*--|o--|--|\\.\\.\\|>|\\.\\.|<--|--\\|>)"),
        
        // ER relationships
        Mode(scope: "keyword", begin: "(?:\\|\\|--o\\{|\\}o--\\|\\||\\|\\|--\\|\\{|\\}\\|--\\|\\||o\\{--\\|\\||\\|\\|--\\{o|\\|\\|\\.\\.o\\{|\\}o\\.\\.\\|\\||\\|\\|\\.\\.|\\{|\\}\\|\\.\\.|\\||o\\{\\.\\.|\\||\\|\\.\\.|\\{o)"),
        
        // State transitions
        Mode(scope: "keyword", begin: "(?:-->|:-->)"),
        
        // Link text (pipe separated)
        Mode(scope: "string", begin: "\\|", end: "\\|"),
        
        // CSS class assignment
        Mode(scope: "meta", begin: ":::"),
        
        // Style definitions
        Mode(scope: "function", begin: "\\bstyle\\s+[a-zA-Z0-9_-]+"),
        Mode(scope: "function", begin: "\\bclassDef\\s+[a-zA-Z0-9_-]+"),
        Mode(scope: "function", begin: "\\blinkStyle\\s+\\d+"),
        
        // Click/callback
        Mode(scope: "function", begin: "\\b(?:click|call)\\s+[a-zA-Z0-9_-]+"),
        
        // Participants/Actors
        Mode(scope: "class", begin: "\\b(?:participant|actor)\\s+([a-zA-Z0-9_]+)"),
        
        // Class names
        Mode(scope: "class", begin: "\\bclass\\s+([a-zA-Z0-9_]+)"),
        
        // State names
        Mode(scope: "class", begin: "\\bstate\\s+(?:\"[^\"]*\"|[a-zA-Z0-9_]+)"),
        
        // Numbers
        Mode(scope: "number", begin: "\\b\\d+(?:\\.\\d+)?\\b"),
        
        // Percentages (for pie charts)
        Mode(scope: "number", begin: "\\b\\d+(?:\\.\\d+)?%"),
        
        // Dates (for Gantt)
        Mode(scope: "string", begin: "\\d{4}-\\d{2}-\\d{2}"),
        
        // Colors (hex)
        Mode(scope: "number", begin: "#[0-9a-fA-F]{3,6}\\b"),
        
        // Colors (rgb/rgba)
        Mode(scope: "function", begin: "rgba?\\("),
        
        // URLs
        Mode(scope: "string", begin: "https?://[^\\s]+"),
        
        // Special state markers
        Mode(scope: "keyword", begin: "\\[\\*\\]"),
        
        // Section headers
        Mode(scope: "class", begin: "^\\s*section\\s+.+$"),
        
        // Title
        Mode(scope: "class", begin: "^\\s*title\\s+.+$"),
    ]
}
