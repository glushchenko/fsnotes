//
//  ScratchLanguage.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 04.12.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

struct ScratchLanguage: LanguageDefinition {
    let name = "Scratch"
    let aliases: [String]? = ["scratch", "sb3"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "keyword": [
            // Motion blocks
            "move", "steps", "turn", "right", "left", "degrees", "go", "to", "goto",
            "random", "position", "glide", "secs", "point", "in", "direction",
            "towards", "mouse-pointer", "change", "x", "by", "y", "set", "if", "on",
            "edge", "bounce", "rotation", "style", "don't", "rotate", "left-right",
            "all", "around",
            // Looks blocks
            "say", "for", "think", "show", "hide", "switch", "costume", "next",
            "backdrop", "size", "effect", "clear", "graphic", "effects",
            // Sound blocks
            "start", "sound", "play", "until", "done", "stop", "all", "sounds",
            "volume", "pitch", "pan", "left", "right",
            // Events blocks
            "when", "green", "flag", "clicked", "key", "pressed", "sprite",
            "stage", "backdrop", "switches", "loudness", "timer", "greater", "than",
            "broadcast", "message", "wait", "receive",
            // Control blocks
            "forever", "repeat", "times", "else", "stop", "this", "script",
            "other", "scripts", "everything", "clone", "create", "myself", "delete",
            // Sensing blocks
            "touching", "color", "distance", "ask", "answer", "down", "username",
            "current", "year", "month", "date", "day", "of", "week", "hour", "minute",
            "second", "days", "since", "2000",
            // Operators blocks
            "mod", "round", "abs", "floor", "ceiling", "sqrt", "sin", "cos", "tan",
            "asin", "acos", "atan", "ln", "log", "pow", "join", "letter", "length",
            "contains",
            // Variables blocks
            "make", "variable", "list", "add", "item", "insert", "at", "replace",
            "with", "contains", "show", "hide",
            // My Blocks (custom blocks)
            "define", "run", "without", "screen", "refresh"
        ],
        "literal": ["true", "false"],
        "built_in": [
            // Motion reporters
            "x position", "y position", "direction",
            // Looks reporters
            "costume number", "costume name", "backdrop number", "backdrop name",
            "size",
            // Sound reporters
            "volume",
            // Sensing reporters
            "answer", "loudness", "timer", "username",
            "mouse x", "mouse y", "mouse down",
            // Operators
            "abs", "floor", "ceiling", "sqrt", "sin", "cos", "tan",
            "asin", "acos", "atan", "ln", "log", "e ^", "10 ^",
            "round", "mod", "pick random", "join", "letter of", "length of",
            "contains", "mathop",
            // Data
            "item of", "length", "item #", "contains",
            // Special values
            "mouse-pointer", "random position", "edge",
            // Backdrops and costumes
            "next backdrop", "previous backdrop", "random backdrop",
            "next costume", "previous costume",
            // Effects
            "color", "fisheye", "whirl", "pixelate", "mosaic", "brightness", "ghost",
            // Sound effects
            "pitch", "pan left/right",
            // Keys
            "space", "up arrow", "down arrow", "right arrow", "left arrow",
            "any", "enter",
            // Special sprites
            "Stage", "Sprite1",
            // Pen (extension)
            "pen down", "pen up", "set pen color", "change pen size",
            "set pen size", "stamp", "erase all",
            // Music (extension)
            "play drum", "rest", "play note", "set instrument", "set tempo",
            "change tempo",
            // Text to Speech (extension)
            "speak", "set voice", "set language",
            // Translate (extension)
            "translate", "language",
            // Video Sensing (extension)
            "video", "motion", "when motion",
            // Makey Makey (extension)
            "when pressed",
            // LEGO (extension)
            "motor", "turn on", "turn off",
            // micro:bit (extension)
            "display", "button"
        ]
    ]
    let contains: [Mode] = [
        // Комментарии (как в JavaScript, так как Scratch часто конвертируется в JS)
        Mode(scope: "comment", begin: "//", end: "\n", contains: []),
        Mode(scope: "comment", begin: "/\\*", end: "\\*/", contains: []),
        
        // Блоки (специальный синтаксис)
        Mode(scope: "function", begin: "\\b(?:define|when|forever|repeat|if|else)\\b"),
        
        // Переменные и списки
        Mode(scope: "meta", begin: "\\b[a-zA-Z_][a-zA-Z0-9_]*\\b(?=\\s*(?:=|<-))"),
        
        // Строки
        CommonModes.stringDouble,
        CommonModes.stringSingle,
        
        // Числа
        // Float
        Mode(scope: "number", begin: "\\b\\d+\\.\\d+\\b"),
        // Integer
        Mode(scope: "number", begin: "\\b\\d+\\b"),
        // Negative numbers
        Mode(scope: "number", begin: "-\\d+\\.?\\d*\\b"),
        
        // Булевы значения и специальные константы
        Mode(scope: "literal", begin: "\\b(?:true|false)\\b"),
        
        // Операторы сравнения и логические
        Mode(scope: "keyword", begin: "(?:and|or|not|<|>|=)"),
        
        // Цвета (в hex формате для Scratch)
        Mode(scope: "number", begin: "#[0-9a-fA-F]{6}\\b"),
    ]
}
