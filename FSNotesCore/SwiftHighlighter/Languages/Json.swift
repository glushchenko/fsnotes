//
//  JsonLanguage.swift
//  FSNotes
//

struct JsonLanguage: LanguageDefinition {
    let name = "JSON"
    let aliases: [String]? = ["json", "jsonc"]
    let caseInsensitive = false
    let keywords: [String: [String]]? = [
        "literal": ["true", "false", "null"]
    ]

    let contains: [Mode] = [
        Mode(scope: "comment", begin: "//", end: "\n"),
        Mode(scope: "comment", begin: "/\\*", end: "\\*/"),

        Mode(scope: "attribute", begin: "\"(?:[^\"\\\\]|\\\\.)*\"(?=\\s*:)"),
        CommonModes.stringDouble,
        Mode(scope: "number", begin: "-?(?:0|[1-9]\\d*)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?"),
        Mode(scope: "operator", begin: "[{}\\[\\],:]")
    ]
}
